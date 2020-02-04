require("dotenv").config();

const path = require("path");
const HDWalletProvider = require("@truffle/hdwallet-provider");

const dev_mnemonic = process.env.ETH_DEV_MNEMONIC;
const infuraProjectId = process.env.INFURA_PROJECT_ID;
const infuraUrl = network => `https://${network}.infura.io/v3/${infuraProjectId}`;

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  contracts_build_directory: path.join(__dirname, "client/src/contracts"),
  mocha: {
    useColors: false
  },
  networks: {
    develop: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*"
    },
    ropsten: {
      provider: () => new HDWalletProvider(dev_mnemonic, infuraUrl("ropsten")),
      network_id: 3
    }
  },
  compilers: {
    solc: {
      version: "0.5.15"
    }
  }
};
