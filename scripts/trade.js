const colors = require("colors");
const hre = require("hardhat");
const ethers = hre.ethers;
const Utils = require("../Utils")
const BN = ethers.BigNumber;
const fsp = require('fs/promises')
const path = require("path")
const uniswapV2RouterAbi = require("../data/uniswap_v2_router.json");
const uniswapV2FactoryAbi = require("../data/uniswap_v2_factory.json");
const uniswapV2PairAbi = require("../data/uniswap_v2_pair.json");
const { exit } = require("process");
let uniswapV2RouterContract;
let weth;
let tokenContract = null;
let uniswapV2RouterAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E"; //pcs
let account;
let TOKEN_DECIMALS = 18;

let  DECIAMLS_BN = BN.from(TOKEN_DECIMALS)
let TOKEN_EXPONENT = BN.from(10).pow(DECIAMLS_BN)


async function main() {

  const locallyDeployedContract = path.resolve("../deployments/localhost/PBull.json")

  console.log(locallyDeployedContract)

  if(!(await Utils.exists(locallyDeployedContract))){
    console.log("Kindly deploy the contract locally first first".red)
    console.log("Run: yarn deploy_local".green)
    exit(1)
  }

  ;[account,_] = await ethers.getSigners();

  //lets read the deployment file 
  let deployedContractText = await fsp.readFile(locallyDeployedContract, {encoding: "utf8"})

  // decode the data 
  try {

    tokenContract = JSON.parse(deployedContractText)

    if(!("address" in tokenContract)){
      new Error("Failed to get deployed contract address")
    }

  } catch(e){
    console.log("Failed to parse deployment file info, kindly redeploy the contract".red)
    console.log("Run: yarn deploy_local".green)
    throw e;
  }
  
  uniswapV2RouterContract = new hre.ethers.Contract(uniswapV2RouterAddress, uniswapV2RouterAbi, account);
  weth = await uniswapV2RouterContract.WETH();

  let buyToken = await buy(ethers.utils.parseEther("0.01"))
}




async function buy(amountETH) {

  let path = [weth, tokenContract.address];
  let buyAmountETH = amountETH;
  let deadline =  ((+new Date()) + 360)

  let buyTokenTx = await uniswapV2RouterContract.swapExactETHForTokensSupportingFeeOnTransferTokens(
      0,
      path,
      account.address,
      deadline,

      // request params
      { value: buyAmountETH } 
  );

  let txReceipt = await buyTokenTx.wait();

   console.log("BUY TX INFO: ", txReceipt)
}



// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});