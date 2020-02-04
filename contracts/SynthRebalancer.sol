pragma solidity >=0.5.15 <0.7.0;

import {Ownable} from "@openzeppelin/contracts/ownership/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SynthInterface, SynthetixInterface} from "./SynthetixInterface.sol";

/**
 * @notice Tool for managing a Synthetix account
 * @notice Rebalance an account's synths to match the global distribution of synths
 * @notice Useful to keep the debt to synth ratio constant when staking SNX
 */
contract SynthRebalancer is Ownable, ReentrancyGuard {
    //----------------------------------------
    // Type definitions
    //----------------------------------------

    using SafeMath for uint256;

    // Used for rebalancing algorithm
    struct SynthNode {
        SynthInterface synth;
        bytes32 currencyKey;
        uint256 balance;
        uint256 synthValue;
        uint256 targetSynthValue;
    }

    // Used to pass information about the account as a function parameter
    struct AccountState {
        address account;
        // Total value of all synths issued to an account
        uint256 accountIssuedSynths;
        // Total value of all globally issued synths
        uint256 totalIssuedSynths;
    }

    //----------------------------------------
    // Constants
    //----------------------------------------

    // Scales values for decimal math
    uint256 private constant DECIMALS_UNIT = 1e18;

    // Base currency for comparing synth value
    bytes32 private constant BASE_CURRENCY_KEY = "sUSD";

    //----------------------------------------
    // State variables
    //----------------------------------------

    SynthetixInterface public synthetix;

    //----------------------------------------
    // Events
    //----------------------------------------

    // Emits when a rebalancing is complete
    event Rebalance(address account);

    // Emits after a synth exchange during rebalancing 
    event Exchange(
        address account,
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey
    );

    //----------------------------------------
    // Constructor
    //----------------------------------------

    constructor(SynthetixInterface _synthetix) public {
        synthetix = _synthetix;
    }

    //----------------------------------------
    // Setter functions
    //----------------------------------------

    function setSynthetix(SynthetixInterface _synthetix) external onlyOwner {
        synthetix = _synthetix;
    }

    //----------------------------------------
    // External functions
    //----------------------------------------

    /**
     * @notice Rebalance an account's synths to match the global distribution of synths
     * @dev Uses reentrancy guard for call to Synthetix contract from `balanceSynths`.
     * @dev TODO: Add a fee paid to the owner
     */
    function rebalance() external nonReentrant {
        AccountState memory accountState = AccountState(
            msg.sender,
            issuedSynths(msg.sender, BASE_CURRENCY_KEY),
            synthetix.totalIssuedSynths(BASE_CURRENCY_KEY)
        );

        SynthNode[] memory synthGraph = getSynthGraph(accountState);

        // Greedy algorithm for rebalancing
        for (uint256 i = 0; i < synthGraph.length; i++) {

            // Check if the synth balance needs to be reduced
            if (synthGraph[i].synthValue > synthGraph[i].targetSynthValue) {
                for (uint256 j = 0; j < synthGraph.length; j++) {

                    // Check if the other synth balance needs to be increased
                    if (
                        i != j
                        && synthGraph[j].synthValue < synthGraph[j].targetSynthValue
                    ) {
                        // Bring synths closer to their targets by exchanging one for the other
                        balanceSynths(synthGraph[i], synthGraph[j], accountState);
                    }
                }
            }
        }

        emit Rebalance(msg.sender);
    }

    //----------------------------------------
    // Public functions
    //----------------------------------------

    //----------------------------------------
    // Public views
    //----------------------------------------

    /**
     * @notice Total value of Synths issued to an account, priced in currencyKey
     * @param account The account to check
     * @param currencyKey The currency to value the synths in
     * @return The total value of the Synths
     */
    function issuedSynths(address account, bytes32 currencyKey)
        public
        view
        returns (uint256)
    {
        uint256 total = 0;

        bytes32[] memory currencyKeys = synthetix.availableCurrencyKeys();
        for (uint256 i = 0; i < currencyKeys.length; i++) {
            total = total.add(synthetix.effectiveValue(
                currencyKeys[i],
                synthetix.synths(currencyKeys[i]).balanceOf(account),
                currencyKey
            ));
        }

        return total;
    }

    /**
     * @notice Get the global distribution of value among Synths
     * @return An array of distributions expressed as a decimal to the 1e18
     */
    function getTotalDistribution() public view returns (uint256[] memory) {
        uint256 totalIssuedSynths = synthetix.totalIssuedSynths(BASE_CURRENCY_KEY);

        bytes32[] memory currencyKeys = synthetix.availableCurrencyKeys();

        uint256[] memory synthDistribution = new uint256[](currencyKeys.length);

        for (uint256 i = 0; i < currencyKeys.length; i++) {
            synthDistribution[i] = synthetix.effectiveValue(
                currencyKeys[i],
                synthetix.synths(currencyKeys[i]).totalSupply(),
                BASE_CURRENCY_KEY
            )
            .mul(DECIMALS_UNIT)
            .div(totalIssuedSynths);
        }

        return synthDistribution;
    }

    //----------------------------------------
    // Private functions
    //----------------------------------------

    /**
     * @notice Balances two Synths to bring them closer to their target values
     * @param synthOverTarget The synth that is over its target value
     * @param synthUnderTarget The synth that is under its target value
     * @param accountState Account state necessary for updating nodes after balancing
     */
    function balanceSynths(
        SynthNode memory synthOverTarget,
        SynthNode memory synthUnderTarget,
        AccountState memory accountState
    ) private {
        // Get difference between current and target values for both synths
        uint256 synthOverValueToExchange = synthOverTarget.synthValue
            .sub(synthOverTarget.targetSynthValue);
        uint256 synthUnderValueToExchange = synthUnderTarget.targetSynthValue
            .sub(synthUnderTarget.synthValue);

        // Do not exchange more than necessary or more than is available
        uint256 valueToExchange = synthOverValueToExchange > synthUnderValueToExchange
            ? synthOverValueToExchange
            : synthUnderValueToExchange;

        // Amount of synth units to exchange
        uint256 sourceAmount = synthOverTarget.synthValue
            .mul(DECIMALS_UNIT)
            .div(synthOverTarget.balance)
            .mul(valueToExchange)
            .div(DECIMALS_UNIT);

        synthetix.exchange(
            synthOverTarget.currencyKey,
            sourceAmount,
            synthUnderTarget.currencyKey
        );

        // Update graph
        synthOverTarget = getUpdatedSynthNode(synthOverTarget, accountState);
        synthUnderTarget = getUpdatedSynthNode(synthUnderTarget, accountState);

        emit Exchange(
            msg.sender,
            synthOverTarget.currencyKey,
            sourceAmount,
            synthUnderTarget.currencyKey
        );
    }

    //----------------------------------------
    // Private views
    //----------------------------------------

    /**
     * @notice Get a synth graph for an account
     * @param accountState The account state to get the synth graph from
     * @return The synth graph
     */
    function getSynthGraph(AccountState memory accountState)
        private
        view
        returns (SynthNode[] memory)
    {
        bytes32[] memory currencyKeys = synthetix.availableCurrencyKeys();

        SynthNode[] memory synthGraph = new SynthNode[](currencyKeys.length);

        // Loop through each synth
        for (uint256 i = 0; i < currencyKeys.length; i++) {
            synthGraph[i] = getSynthNode(currencyKeys[i], accountState);
        }

        return synthGraph;
    }

    /**
     * @notice Get a synth node
     * @param currencyKey The type of synth to get a node for
     * @param accountState The accountState used for calculating the synth node
     * @return The synth node
     */
    function getSynthNode(bytes32 currencyKey, AccountState memory accountState)
        private
        view
        returns (SynthNode memory)
    {
        return getUpdatedSynthNode(
            SynthNode(synthetix.synths(currencyKey), currencyKey, 0, 0, 0),
            accountState
        );
    }

    /**
     * @notice Get the most recent version of the specified synth node
     * @param node The synth node to update
     * @param accountState The accountState used for calculating the synth node
     * @return Latest version of synth node
     */
    function getUpdatedSynthNode(SynthNode memory node, AccountState memory accountState)
        private
        view
        returns (SynthNode memory)
    {
        // Proportion of synth value against total issued synth value
        uint256 totalSynthDistribution = synthetix.effectiveValue(
            node.currencyKey,
            node.synth.totalSupply(),
            BASE_CURRENCY_KEY
        )
        .mul(DECIMALS_UNIT)
        .div(accountState.totalIssuedSynths);

        // Balance of synth for account
        node.balance = node.synth.balanceOf(accountState.account);

        // Value of synth issued to an account
        node.synthValue = synthetix.effectiveValue(
            node.currencyKey,
            node.balance,
            BASE_CURRENCY_KEY
        );

        // Value of synth issued to an account that would match the global distribution
        node.targetSynthValue = accountState.accountIssuedSynths
            .mul(totalSynthDistribution)
            .div(DECIMALS_UNIT);

        return node;
    }
}
