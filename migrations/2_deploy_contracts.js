const SynthRebalancer = artifacts.require("SynthRebalancer");
const snx = require("synthetix");

module.exports = function(deployer, network) {
  let synthetixAddress = snx.getTarget({
    network: network.replace("-fork", ""),
    contract: "Synthetix"
  }).address;

  deployer.deploy(SynthRebalancer, synthetixAddress);
};
