const path = require('path')
const Utils = require('../Utils');
const hre = require("hardhat")
const secretsObj = require("../.secrets.js");
const uniswapV2Abi = require("../data/uniswap_v2_router.json");
const sleep = require("sleep");
const BN = ethers.BigNumber;

let displayLog = true;

module.exports = async (opts) => {
    return (await runDeployment(opts));
} //end for 

module.exports.tags = ['PBull'];

//export
module.exports.runDeployment = runDeployment;


/**
 * runDeployment
 */
async function runDeployment(options = {}){
    
    try{
        
        let {getUnnamedAccounts, deployments, ethers, network} = options;

        let isTestCase = options.isTestCase || false;

        if(isTestCase) { displayLog = false; }

        let deployedContractsObj = {}
 
        const {deploy} = deployments;
        const accounts = await getUnnamedAccounts();

        let signers = await hre.ethers.getSigners()

        let uniswapV2Router;

        let networkName = network.name;

        let isTestnet;

        console.log()
        console.log("Network or Chain Info ===>> ")
        console.log(await ethers.provider.getNetwork())
        console.log()
        
        let hardhatRouter = "0x10ED43C718714eb63d5aA57B78B54704E256024E"

        //lets get some vars
        if(["kovan","ethereum_mainnet","ropsten","rinkeby"].includes(networkName)){
            
            uniswapV2Router = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
        } 

        /// localhost or hardhat
        else if(["localhost","local","hardhat"].includes(networkName)){
            uniswapV2Router = hardhatRouter;
        }
        else if(["bsc_mainnet"].includes(networkName)) { //pancake swap
            
            uniswapV2Router = "0x10ED43C718714eb63d5aA57B78B54704E256024E";

        } else if(networkName == "bsc_testnet"){ 

            uniswapV2Router = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3"; //"0xD99D1c33F9fC3444f8101754aBC46c52416550D1";

        } else {
            throw new Error("Unknown uniswapV2Router for network "+ network)
        }
        

        if(["kovan","rinkeby","ropsten","localhost","hardhat","local","bsc_testnet"].includes(networkName)){
            isTestnet = true;
        } else {
            isTestnet = false;
        }

        deployedContractsObj["uniswapV2Router"] = uniswapV2Router;

        let account = accounts[0];

        //deploy factory
        let deployedTokenContract = await deploy('PBull', {
            from: account,
            log:  false
        });

        let tokenContractAddress = deployedTokenContract.address;

        printDeployedInfo("PBull", deployedTokenContract);

        deployedContractsObj["tokenContractAddress"] = tokenContractAddress;

        //console.log("ethers ===>>", ethers)
        
        //return false;

        const tokenContractInstance = await ethers.getContract("PBull", account);
        
        Utils.infoMsg("Deploying HoldlersRewardComputer contract");

        //deploying  HoldlersRewardComputer.sol
        let deployedHoldlersRewardContract = await deploy('HoldlersRewardComputer', {
            from: account,
            args: [tokenContractAddress],
            log:  false
        });

        let holdlersRewardComputer = deployedHoldlersRewardContract.address;

        printDeployedInfo("HoldlersRewardComputer", deployedHoldlersRewardContract);

        deployedContractsObj["holdlersRewardComputer"] = holdlersRewardComputer;


        Utils.infoMsg("Deploying SwapEngine contract");

        //deploying  swapEngine.sol
        let deployedSwapEngine = await deploy('SwapEngine', {
            from: account,
            args: [tokenContractAddress, uniswapV2Router],
            log:  false
        });

        printDeployedInfo("SwapEngine", deployedSwapEngine);

        let swapEngineAddress = deployedSwapEngine.address;

        deployedContractsObj["swapEngine"] = swapEngineAddress;

        console.log("deployedContractsObj ==>> ", deployedContractsObj)

        let _initializeParams = [
            uniswapV2Router,  
            swapEngineAddress,
            holdlersRewardComputer
        ];

        let gasEstimate = await tokenContractInstance.estimateGas._initializeContract(..._initializeParams);

        // lets initialize token contract  , gasPrice:  ethers.utils.parseUnits('90', 'gwei')
        let initializeTokenContract = await tokenContractInstance._initializeContract(
            ..._initializeParams,
            {  gasLimit: gasEstimate   }
        );  

        await initializeTokenContract.wait();
        
        printEthersResult("initializeTokenContract", initializeTokenContract)


        if(!isTestnet){

           /* Utils.infoMsg(`Publishing contract PBull Token to etherscan`)

            await publishToEtherscan(tokenContractAddress);

            Utils.successMsg(`PBullToken published to etherscan`)
            */
        }


        if(["localhost","local","hardhat"].includes(networkName)) {

            let swapEngineInstance = await ethers.getContract("SwapEngine", account);
            await handleTestNetOperations(account, tokenContractInstance, swapEngineInstance, isTestCase);
        }

        //adding first liquidity

        //lets update token contract of 

        return Promise.resolve(deployedContractsObj);
    } catch (e){
        console.log(e,e.stack)
    }
} //end function 




function printDeployedInfo(contractName,deployedObj){

    if(!displayLog) return;

    Utils.successMsg(`${contractName} deployment successful`)
    Utils.successMsg(`${contractName} contract address: ${deployedObj.address}`)
    Utils.successMsg(`${contractName} txHash: ${deployedObj.transactionHash}`)
    //Utils.successMsg(`${contractName} gas used: ${deployedObj.receipt.cumulativeGasUsed}`)
    console.log()
}


function printEthersResult(contractName,resultObj){

     if(!displayLog) return;

    Utils.successMsg(`${contractName} txHash: ${resultObj.hash}`)
    //Utils.successMsg(`${contractName} Confirmations: ${resultObj.confirmations}`)
    //Utils.successMsg(`${contractName} Block Number: ${resultObj.blockNumber}`)
    //Utils.successMsg(`${contractName} Nonce: ${resultObj.nonce}`)
}


/**
 * publish to etherscan
 */
async function publishToEtherscan(contractAddress){
    await hre.run("verify:verify", {
        address: contractAddress
    })
}


async function handleTestNetOperations(
    account,
    tokenContractInstance,
    swapEngineInstance,
    isTestCase
) {

    let signer = await ethers.getSigner(account);

    Utils.infoMsg("Sending Ether to Contract")

    let amountETHToSend = '1'

    // lets send ethers to the contract 
    let sendTx = await signer.sendTransaction({
        to: tokenContractInstance.address,
        value: ethers.utils.parseEther(amountETHToSend)
    })

    await sendTx.wait()

     Utils.successMsg(`Sent Ether to Contract: ${sendTx.hash}`)

    let liquidityParams = secretsObj.initialLiquidityParams || {}
    let tokenAMount = liquidityParams.tokenAMount || 0;
    let baseAssetAmount = liquidityParams.baseAssetAmount || 0;

    const tokenDecimals = await tokenContractInstance.decimals();

    let tokenDecimalExponent = BN.from(10).pow(BN.from(tokenDecimals));

    if(Object.keys(liquidityParams).length > 0 && 
        tokenAMount > 0 &&
        baseAssetAmount > 0
    ) {

        let tokenAMountWei;

        //multiply each amount by 100 to remove it from fraction value,
        // after divide by 100 to get original value, else BigNumber will 
        // give underflow error
        if(tokenAMount < 1){
            tokenAMountWei = BN.from((tokenAMount * 100)).mul(tokenDecimalExponent).div(BN.from(100));
        } else {
            tokenAMountWei =  BN.from(tokenAMount).mul(tokenDecimalExponent)
        }

        let baseAssetAmountWei;

        if(baseAssetAmount < 1){
           baseAssetAmountWei = ethers.utils.parseEther((baseAssetAmount * 100).toString()).div(BN.from(100));
        } else {
            baseAssetAmountWei = ethers.utils.parseEther(baseAssetAmount.toString());
        }
        
        Utils.infoMsg(`Approving Token on : ${swapEngineInstance.address}`);

        //lets approve the swap engine cntract first
        let approveSwapEngineTx =  await tokenContractInstance.approve(swapEngineInstance.address, tokenAMountWei);

        approveSwapEngineTx.wait();

        Utils.successMsg(`Token Approval Successful: ${approveSwapEngineTx.hash}`);

       
        let addLiquidityResult = await swapEngineInstance.addInitialLiquidity(
                                tokenAMountWei, 
                                {value: baseAssetAmountWei, gasLimit: 6000000, gasPrice:  ethers.utils.parseUnits('40', 'gwei') }
        );

        await addLiquidityResult.wait();

        //deployedContractsObj["addLiquityTxHash"] = addLiquidityResult.hash;

        Utils.successMsg(`Uniswap V2 Liquidity Added, txHash: ${addLiquidityResult.hash}`);
    }


    if(!isTestCase){

        //lets send out some tokens to test accounts on testnets
        let testAccountsArray = secretsObj.testAccounts || [];

        let testTokenToSend = BN.from(2000000).mul(tokenDecimalExponent);

        for(let i in testAccountsArray) {

            let _address = testAccountsArray[i];


             Utils.infoMsg(`Sending ${testTokenToSend} to ${_address}`);

            let transfer = await tokenContractInstance.transfer(
                _address,
                testTokenToSend,
                {gasLimit: 6000000, gasPrice:  ethers.utils.parseUnits('40', 'gwei') }
            );

            Utils.successMsg(`Token transfer to ${_address} Success: Hash: ${transfer.hash}`);
           
            //sleep
            sleep.sleep((i + 1) * 2);
        } //end loop
    } //end if testNet 

}