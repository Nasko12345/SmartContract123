require("@nomiclabs/hardhat-waffle");

require("@nomiclabs/hardhat-ethers");

require("@nomiclabs/hardhat-etherscan");

require('hardhat-contract-sizer');

require('hardhat-deploy');


const {  
  infuraProjectId,
  accountPrivateKey,
  etherscanAPIKey,
  alchemyAPi
} = require(__dirname+'/.secrets.js');


let forkURL = `https://speedy-nodes-nyc.moralis.io/e61c980750ae9b2b93ed4fbf/bsc/mainnet/archive`
//const bscProvider = new ethers.providers.JsonRpcProvider(forkURL);
//const latestBlock = await bscProvider.getBlockNumber();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {

  networks: {

    hardhat: {
      accounts: [{privateKey: `0x${accountPrivateKey}`, balance: "91229544000000000000"}],
      forking: {
          url: forkURL
      },
      loggingEnabled: false,
      mining: {
        auto: true,
        interval: [1000, 5000]
      },

      chainId: 1337
    },

    kovan: {
      url: `https://eth-kovan.alchemyapi.io/v2/${alchemyAPi}`,//`https://kovan.infura.io/v3/${infuraProjectId}`,
      chainId: 42,
      //gasPrice: 20000000000,
      accounts: [`0x${accountPrivateKey}`]
    },  

    ropsten: {
      url:  `https://eth-ropsten.alchemyapi.io/v2/${alchemyAPi}`,//`https://ropsten.infura.io/v3/${infuraProjectId}`,
      chainId: 3,
      //gasPrice: 20000000000,
      accounts: [`0x${accountPrivateKey}`]
    },  

    rinkeby: {
        url: `https://eth-rinkeby.alchemyapi.io/v2/${alchemyAPi}`,
        chainId: 4,
        //gasPrice: 20000000000,
        accounts: [`0x${accountPrivateKey}`]
    },

    eth_mainnet: {
      url:  `https://mainnet.infura.io/v3/${infuraProjectId}`,
      chainId: 1,
      ///gasPrice: 20000000000,
      accounts: [`0x${accountPrivateKey}`]
    },    
    
    bsc_testnet: {
      url:  `https://data-seed-prebsc-2-s3.binance.org:8545/`,
      chainId: 97,
      ///gasPrice: 20000000000,
      accounts: [`0x${accountPrivateKey}`]
    },   
    
    bsc_mainnet: {
      url:  `https://speedy-nodes-nyc.moralis.io/e61c980750ae9b2b93ed4fbf/bsc/mainnet/archive`,
      chainId: 56,
      ///gasPrice: 20000000000,
      accounts: [`0x${accountPrivateKey}`]
    }, 
    
  },

  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: etherscanAPIKey
  },

  solidity: {
    version: "0.8.4",
      settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
      }
  },

  mocha: {
    timeout: 1000000
  }
};

