const networks = require('./hardhat.networks')
require("@nomicfoundation/hardhat-toolbox");
require('hardhat-deploy');
require('hardhat-deploy-ethers');
require("./tasks")
require('hardhat-contract-sizer');
require("dotenv").config()

const PRIVATE_KEY = process.env.PRIVATE_KEY
const PRIVATE_KEY1 = process.env.PRIVATE_KEY1

// address 
OwnerTestAccount = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" // test address Cautions: No real fil for this account
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  namedAccounts: {
    deployer: {
      default: 0
    },
    owner: {
      42: OwnerTestAccount,
      4: OwnerTestAccount,
      3: OwnerTestAccount
    },
    admin: {
      42: OwnerTestAccount,
      4: OwnerTestAccount,
      3: OwnerTestAccount
    }
  },
  defaultNetwork:"hyperspace",
  networks,
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true
  },
  mocha: {
    timeout: 2000000
  }
};