pragma solidity >=0.5.15 <0.7.0;

import {Assert} from "truffle/Assert.sol";
import {MockSynthetix} from "./MockSynthetix.sol";
import {SynthRebalancer} from "../contracts/SynthRebalancer.sol";

contract TestSynthRebalancer {
    function testSynthRebalance() public {
        SynthRebalancer rebalancer = new SynthRebalancer(new MockSynthetix());

        rebalancer.rebalance();

        Assert.equal(
            rebalancer.synthetix().synths("A").balanceOf(address(0)),
            20,
            "Synth A should remain the same"
        );

        Assert.equal(
            rebalancer.synthetix().synths("B").balanceOf(address(0)),
            15,
            "Synth B should be reduced"
        );

        Assert.equal(
            rebalancer.synthetix().synths("C").balanceOf(address(0)),
            30,
            "Synth C should be increased"
        );

        Assert.equal(
            rebalancer.synthetix().synths("D").balanceOf(address(0)),
            30,
            "Synth D should be increased"
        );

        Assert.equal(
            rebalancer.synthetix().synths("E").balanceOf(address(0)),
            5,
            "Synth E should be reduced"
        );
    }
}
