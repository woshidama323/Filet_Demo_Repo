const networks = {

  coverage: {
    url: 'http://127.0.0.1:8555',
    blockGasLimit: 200000000,
    allowUnlimitedContractSize: true
  },
  // localhost: {
  //   // chainId: 1,
  //   url: 'http://127.0.0.1:8545',
  //   allowUnlimitedContractSize: true,
  //   accounts: {
  //     mnemonic: process.env.HDWALLET_MNEMONIC
  //   },
  //   timeout: 1000 * 60
  // }
}
// filecoin network
if (process.env.FILECOIN_Private) {

  networks.filmainnet = {
    chainId: 314,
    url: 'https://api.node.glif.io/rpc/v1',
    accounts: [process.env.FILECOIN_Private,process.env.FILECOIN_Private],
    timeout: 1000 * 60,
  }

  networks.hyperspace = {
    chainId: 3141,
    url: 'https://api.hyperspace.node.glif.io/rpc/v1',
    accounts: [process.env.FILECOIN_Private,process.env.FILECOIN_Private],
    timeout: 1000 * 60,
  }

  networks.calibration = {
    chainId: 314159,
    url: 'https://api.calibration.node.glif.io/rpc/v1',
    accounts: [process.env.FILECOIN_Private,process.env.FILECOIN_Private],
  }

}

if (process.env.HDWALLET_MNEMONIC) {

  networks.bsc = {
    chainId: 56,
    url: 'https://bsc-dataseed.binance.org',
    accounts: {
      mnemonic: process.env.HDWALLET_MNEMONIC
    }
  }
  networks.bscTestnet = {
    chainId: 97,
    url: 'https://data-seed-prebsc-1-s1.binance.org:8545/',
    accounts: {
      mnemonic: process.env.HDWALLET_MNEMONIC
    }
  }
  networks.heco = {
    chainId: 128,
    url: 'https://http-mainnet-node.huobichain.com',
    accounts: {
      mnemonic: process.env.HDWALLET_MNEMONIC
    }
  }
  networks.hecoTestnet = {
    chainId: 256,
    url: 'https://http-testnet.hecochain.com',
    accounts: {
      mnemonic: process.env.HDWALLET_MNEMONIC
    }
  }
}

if (process.env.INFURA_API_KEY && process.env.HDWALLET_MNEMONIC) {
  networks.kovan = {
    url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
    accounts: {
      mnemonic: process.env.HDWALLET_MNEMONIC
    }
  }

} else {
  console.warn('No infura or hdwallet available for testnets')
}

module.exports = networks
