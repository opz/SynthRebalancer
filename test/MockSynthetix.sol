pragma solidity >=0.5.15 <0.7.0;

import {SynthetixInterface} from "../contracts/SynthetixInterface.sol";

contract MockSynth {
    uint256 private supply;
    uint256 private balance;

    constructor(uint256 _totalSupply, uint256 _balance) public {
        supply = _totalSupply;
        balance = _balance;
    }

    function mint(uint256 amount) external {
        balance += amount;
    }

    function burn(uint256 amount) external {
        require(balance >= amount);
        balance -= amount;
    }

    function totalSupply() external view returns (uint256) {
        return supply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balance;
    }
}

contract MockSynthetix is SynthetixInterface {
    bytes32[] private currencyKeys;
    mapping(bytes32 => MockSynth) public synths;

    constructor() public {
        currencyKeys.push("A");
        currencyKeys.push("B");
        currencyKeys.push("C");
        currencyKeys.push("D");
        currencyKeys.push("E");

        synths["A"] = new MockSynth(20, 20);
        synths["B"] = new MockSynth(15, 40);
        synths["C"] = new MockSynth(30, 10);
        synths["D"] = new MockSynth(30, 15);
        synths["E"] = new MockSynth(5, 15);
    }

    function effectiveValue(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    )
        public
        view
        returns (uint)
    {
        return sourceAmount;
    }

    function totalIssuedSynths(bytes32 currencyKey)
        public
        view
        returns (uint256)
    {
        return 100;
    }

    function availableCurrencyKeys() public view returns (bytes32[] memory) {
        return currencyKeys;
    }

    function exchange(bytes32 sourceCurrencyKey, uint sourceAmount, bytes32 destinationCurrencyKey)
        external
        returns (bool)
    {
        synths[sourceCurrencyKey].burn(sourceAmount);
        synths[destinationCurrencyKey].mint(sourceAmount);
    }
}
