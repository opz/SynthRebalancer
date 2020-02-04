const SynthRebalancer = artifacts.require("SynthRebalancer");
const snx = require("synthetix");
const { constants } = require("@openzeppelin/test-helpers");

module.exports = function(deployer, network) {
  let synthetixAddress;

  try {
    synthetixAddress = snx.getTarget({
      network: network.replace("-fork", ""),
      contract: "Synthetix"
    }).address;
  } catch {
    synthetixAddress = constants.ZERO_ADDRESS;
  }

  deployer.deploy(SynthRebalancer, synthetixAddress);
};
