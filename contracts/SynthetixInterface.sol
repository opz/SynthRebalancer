pragma solidity >=0.5.15 <0.7.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SynthInterface is IERC20 {
}

contract SynthetixInterface {
    SynthInterface[] public availableSynths;
    mapping(bytes32 => SynthInterface) public synths;
    mapping(address => bytes32) public synthsByAddress;

    function effectiveValue(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    )
        public
        view
        returns (uint);

    function totalIssuedSynths(bytes32 currencyKey) public view returns (uint);

    function availableCurrencyKeys() public view returns (bytes32[] memory);

    function exchange(bytes32 sourceCurrencyKey, uint sourceAmount, bytes32 destinationCurrencyKey)
        external
        returns (bool);
}
