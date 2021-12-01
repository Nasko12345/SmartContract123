const { expect } = require('chai')
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
const deployer = require("../deploy/deploy.js");
const sleep = require('sleep');

const descTitle = (msg) => {
    return `\r\n ${colors.italic.underline.green(msg)}\r\n`;
}

describe(descTitle('Token Contract Test'), function () {

    let DECIAMLS = 18;
    let TOTAL_SUPPLY = 26_000_000;
    let TOKEN_NAME = "Luckie Jodjie 2";
    let TOKEN_SYMBOL = "LLJ";

    let DECIAMLS_BN = BN.from(DECIAMLS)

    let TOKEN_EXPONENT = BN.from(10).pow(DECIAMLS_BN)

    let TOTAL_SUPPLY_BN = BN.from(TOTAL_SUPPLY).mul(TOKEN_EXPONENT);

    let ETH_AMOUNT_FOR_LIQUIDITY = 0.001;

    let TOKEN_AMOUNT_FOR_LIQUIDITY_BN = BN.from(1000).mul(TOKEN_EXPONENT);

    let ETH_AMOUNT_FOR_LIQUIDITY_BN = ethers.utils.parseEther((ETH_AMOUNT_FOR_LIQUIDITY * 100).toString()).div(BN.from(100));
    
    let account;

    let randomWallet;

    let deployedContractsInfo;

    let tokenContract;

    let isDeployed = false;
 
    beforeEach(async function () {
        
        if(!isDeployed){
            deployedContractsInfo = await deployer.runDeployment({...hre, isTestCase: true})
            isDeployed = true;
        }

        ;[account,_] = await ethers.getSigners();

        tokenContract = await ethers.getContract("PBull", account)

        //console.log("tokenContract ====>>> ", tokenContract.address)

        randomWallet = await Utils.createRandomWallet();

    }); // end before each

    describe(descTitle('Post Deployemt Checks'), async  () => {
       
        it('Should match the deployed owner', async  () => {
            expect(await tokenContract.owner()).to.equal(account.address)
        });

        
        it(`Should match required token supply ${TOTAL_SUPPLY_BN}`, async  () => {
            expect((await tokenContract.totalSupply()).toString()).to.equal(TOTAL_SUPPLY_BN.toString())
        });

        it(`Should match required token decimals  ${DECIAMLS}`, async  () => {
            expect((await tokenContract.decimals())).to.equal(DECIAMLS_BN)
        });

        it(`Should match token name: ${TOKEN_NAME}`, async  () => {
            expect((await tokenContract.name()).toString()).to.equal(TOKEN_NAME)
        });

        it(`Should match token symbol: ${TOKEN_SYMBOL}`, async  () => {
            expect((await tokenContract.symbol()).toString()).to.equal(TOKEN_SYMBOL)
        });



        // lets check if the fee matches to what we want 
        it('Should match total enabled fee sum', async () => {


            let fee = BN.from('0');

            // get all the fee
            if((await tokenContract.isDevFeeEnabled())) fee = fee.add(await tokenContract.devFee());
            if((await tokenContract.isMarketingFeeEnabled())) fee = fee.add(await tokenContract.marketingFee());
            if((await tokenContract.isAutoLiquidityEnabled())) fee = fee.add(await tokenContract.autoLiquidityFee());
            if((await tokenContract.isHoldlersRewardEnabled())) fee = fee.add(await tokenContract.holdlersRewardFee());
            if((await tokenContract.isBuyBackEnabled())) fee = fee.add(await tokenContract.buyBackFee());
            if((await tokenContract.isSellTaxEnabled())) fee = fee.add(await tokenContract.sellTaxFee());

            //lets get user based fee 
            //let accountExtraTax = await tokenContract.perAccountExtraTax(randomWallet.address)

            //fee = fee.add(accountExtraTax);

            // if expected fee is met
            expect((await tokenContract.getTotalFee()).toString()).to.equal(fee.toString());
        });
        
    }) //end token basics

    // test fees and limits
    describe(descTitle('Test Fees, Excludes & Limits'), async  () => {

        it(`Should  exclude from fee`, async  () => {
            let excludeFromFeeTx = await tokenContract.excludeFromFees(randomWallet.address, true)
            await excludeFromFeeTx.wait();
            expect((await tokenContract.excludedFromFees(randomWallet.address))).to.equal(true)
        });


        it(`Should  exclude from rewards`, async  () => {
            let excludeFromRewardsTx = await tokenContract.excludeFromRewards(randomWallet.address, true)
            await excludeFromRewardsTx.wait();
            expect((await tokenContract.excludedFromRewards(randomWallet.address))).to.equal(true)
        });

        // excludedFromMaxTxAmountLimit
        /*
        it(`Should  exclude from max_tx_amount_limit`, async  () => {
            let excludeFromMaxTxAmountLimitTx = await tokenContract.excludeFromMaxTxAmountLimit(randomWallet.address, true)
            await excludeFromMaxTxAmountLimitTx.wait();
            expect((await tokenContract.excludedFromMaxTxAmountLimit(randomWallet.address))).to.equal(true)
        });*/


        ////////////////// Remove from excludes

        it(`Should remove from excluded fees`, async  () => {
            let excludeFromFeeTx = await tokenContract.excludeFromFees(randomWallet.address, false)
            await excludeFromFeeTx.wait();
            expect((await tokenContract.excludedFromFees(randomWallet.address))).to.equal(false)
        });


        it(`Should remove from excluded rewards`, async  () => {
            let excludeFromRewardsTx = await tokenContract.excludeFromRewards(randomWallet.address, false)
            await excludeFromRewardsTx.wait();
            expect((await tokenContract.excludedFromRewards(randomWallet.address))).to.equal(false)
        });

        /*/ excludedFromMaxTxAmountLimit
        it(`Should remove  from exclude  max_tx_amount_limit`, async  () => {
            let excludeFromMaxTxAmountLimitTx = await tokenContract.excludeFromMaxTxAmountLimit(randomWallet.address, false)
            await excludeFromMaxTxAmountLimitTx.wait();
            expect((await tokenContract.excludedFromMaxTxAmountLimit(randomWallet.address))).to.equal(false)
        });*/


        // send transaction with fee
        it(`Should  transfer tokens with fee successfully`, async  () => {

            let excludeFromFeeTx = await tokenContract.excludeFromFees(account.address, false)
            await excludeFromFeeTx.wait();

            let amountToSend = 1000;
            
            let transferTx = await tokenContract.transfer(randomWallet.address, amountToSend);

            await transferTx.wait();

            //lets get the fee and check the amount sent by checking user balance
            let totalFeesInBPS = (await tokenContract.getTotalFee()).toNumber();

            // lets remove the sell tax
            let sellOnlyTax = (await tokenContract.sellTaxFee()).toNumber();

            totalFeesInBPS = totalFeesInBPS - sellOnlyTax;

            //expected balance 
            let expectedBalance = amountToSend - ((totalFeesInBPS / 10_000) * amountToSend);

            //console.log("expected Balance: ", expectedBalance.toString() )

            expect((await tokenContract.balanceOf(randomWallet.address)).toString()).to.equal(expectedBalance.toString())
        });

        /*
        it(`Should pass if transaction amount exceeds max_tx_amount_limit`, async  () => {

            let excludeFromMaxTxAmountLimitTx = await tokenContract.excludeFromMaxTxAmountLimit(account.address, false)
            
            await excludeFromMaxTxAmountLimitTx.wait();

            let paramHash = ethers.utils.solidityKeccak256(["string"], ["TX_ALL"]);

            //console.log("paramHash ====>>>>>>>>>", paramHash)

            //lets set setTxTypeForMaxTxAmountLimit to TX_ALL
            let updateMaxTxAmountType = await tokenContract.setTxTypeForMaxTxAmountLimit(paramHash)

            await updateMaxTxAmountType.wait()

            // lets get max transfer amount limit
            let maxTxAmountPercent = (await tokenContract.maxTxAmountLimitPercent());

            //total supply 
            let totalSupply = await tokenContract.totalSupply();

            //max tx limit amount 
            let txAmountLimit = (totalSupply.mul(maxTxAmountPercent)).div(BN.from("10000"))

            // lets send more than 2 times the amount
            let amountToSend = txAmountLimit.add(BN.from("1000").mul(TOKEN_EXPONENT))

            // the transaction must fail for test to pass
            let testPassed = false;
            
            try{

               let transferTx = await tokenContract.transfer(randomWallet.address, amountToSend);
                await transferTx.wait();

                if(transferTx.status == 1) testPassed = false;

                console.log(transferTx)
            } catch(e){
                
                if(e.toString().includes("PBULL: AMOUNT_EXCEEDS_TRANSFER_LIMIT")){
                    testPassed = true;
                } else {
                    testPassed = false;
                    throw e;
                }
            }

            // the transaction should fail
            expect(testPassed).to.equal(true)

        });


        it(`Should successfully throttle an account`, async  () => {

            let timeIntervalPerTx = 60 * 60;

            let throttleAccountTx = await tokenContract.throttleAccountTx(
                    account.address, 
                    50, // 0.5% of max supply
                    timeIntervalPerTx, // can send  1% of max tx every 1hour
            )
            await throttleAccountTx.wait();
            
            let accountThrottleInfo = await tokenContract.throttledAccounts(account.address);
            
            expect( accountThrottleInfo.timeIntervalPerTx.toNumber()  ).to.equal(timeIntervalPerTx);
        });



        it(`Should fail if throttled account transfer amount exceeds txAmountLimitPercent`, async  () => {


            //total supply 
            let totalSupply = await tokenContract.totalSupply();

            let accountThrottleInfo = await tokenContract.throttledAccounts(account.address);

            //max tx limit amount 
            let txAmountLimit = (totalSupply.mul(accountThrottleInfo.txAmountLimitPercent)).div(BN.from("10000"))

            // lets send more than 2 times the amount
            let amountToSend = txAmountLimit.mul(BN.from("2"))

            // the transaction must fail for test to pass
            let testPassed = false;

            try{

                let transferTx = await tokenContract.transfer(randomWallet.address, amountToSend);
                await transferTx.wait();

                if(transferTx.status == 1) testPassed = false;

            } catch(e){
                if(e.toString().includes("ACCOUNT_THROTTLED_AMOUNT_EXCEEDS_")){
                    testPassed = true;
                } else {
                    testPassed = false;
                    throw e;
                }
            }

            // the transaction should fail
            expect(testPassed).to.equal(true)
        });


        it(`Should successfully unthrottle an account`, async  () => {

            let throttleAccountTx = await tokenContract.unThrottleAccountTx(account.address);

            await throttleAccountTx.wait();
            
            let accountThrottleInfo = await tokenContract.throttledAccounts(account.address);
            
            expect( accountThrottleInfo.timeIntervalPerTx.toNumber()  ).to.equal( 0 );
        });
        */
    }); //end limits, throttles and feees
    

    ///////// Reward system
    describe(descTitle('Test Reward System'), async  () => {
        
        it(`Should match HoldleRewardComputer`, async  () => {
            expect((await tokenContract.holdlersRewardComputer())).to.equal( deployedContractsInfo.holdlersRewardComputer )            
        });

         //lets now set the setMinExpectedHoldlPeriod
         it(`Should update HoldleRewardComputer.setRewardStartDelay Successfully`, async  () => {

            let rewardStartDelay = 1; //10 secs
            let setRewardStartDelayTx = await tokenContract.setRewardStartDelay(rewardStartDelay);

            await setRewardStartDelayTx.wait();

            expect( (await tokenContract.rewardStartDelay()).toNumber()  ).to.equal( rewardStartDelay );
        });

        //lets now set the setMinExpectedHoldlPeriod
        it(`Should match HoldleRewardComputer setMinExpectedHoldlPeriod`, async  () => {

            let maxHoldlePeriod = 5; //10 secs
            let setMinExpectedHoldlPeriodTx = await tokenContract.setMinExpectedHoldlPeriod(maxHoldlePeriod);

            await setMinExpectedHoldlPeriodTx.wait();

            expect( (await tokenContract.minExpectedHoldlPeriod()).toNumber()  ).to.equal( maxHoldlePeriod );
        });

        //lets now set the setMinExpectedHoldlPeriod
        it(`Should match computed results account will get `, async  () => {

            let rewardStartDelay = 0; //10 secs
            let setRewardStartDelayTx = await tokenContract.setRewardStartDelay(rewardStartDelay);

            await setRewardStartDelayTx.wait();


            let maxHoldlePeriod = 1; //10 secs
            let setMinExpectedHoldlPeriodTx = await tokenContract.setMinExpectedHoldlPeriod(maxHoldlePeriod);

            await setMinExpectedHoldlPeriodTx.wait();

            let rewardableUserWallet = await Utils.createRandomWallet();

            console.log("rewardableUserWallet.address====>>>", rewardableUserWallet)

            let amountToSend = BN.from("1000000").mul(TOKEN_EXPONENT);

            // we want exactly 1000 to be sent
            let excludeFromFeeTx = await tokenContract.excludeFromFees(rewardableUserWallet.address, true)
            await excludeFromFeeTx.wait();

            let transferTx = await tokenContract.transfer(rewardableUserWallet.address, amountToSend);
            
            await transferTx.wait();

             //total supply 
            let totalSupply = await tokenContract.totalSupply();

            let newAccountBalance = await tokenContract.realBalanceOf(rewardableUserWallet.address);

            //lets get the rewrd pool
            let holdlersRewardsPool = await tokenContract.holdlersRewardMainPool();

            //lets get account info 
            let holdlerInfo =  await tokenContract.getHoldlerInfo(rewardableUserWallet.address)

            //lets compute user reward and match
            let holdledDuration = (+new Date()) - (holdlerInfo.initialDepositTimestamp).toNumber();

            let minExpectedHoldlPeriod = (await tokenContract.minExpectedHoldlPeriod()).toNumber();

            //lets sleep for 11 seconds then compute the rewards
            sleep.sleep(maxHoldlePeriod+5);

            
            let perentageOfTimeHoldledAgainstRequired = (holdledDuration * minExpectedHoldlPeriod) / 100;

            //cap to 100%
            if(perentageOfTimeHoldledAgainstRequired > 0){
                perentageOfTimeHoldledAgainstRequired = 100;
            }

            //lets supply based reward
            //let reward = 
            let balanceBasedReward = (newAccountBalance.mul(holdlersRewardsPool)).div(totalSupply);

            let reward = (BN.from(perentageOfTimeHoldledAgainstRequired.toString()).mul(balanceBasedReward)).div(BN.from("100"))

            let finalReward = 0;

            if(reward >= holdlerInfo.totalRewardReleased){
                finalReward = reward.sub(holdlerInfo.totalRewardReleased);
            }

            console.log("getRewards ===>> ", (await tokenContract.getReward(rewardableUserWallet.address)).toString());

            //expect((await tokenContract.getReward(rewardableUserWallet.address)).toString()).to.equal(reward.toString());
            expect((await tokenContract.getReward(rewardableUserWallet.address)).toString()).to.equal(finalReward.toString());
        });
        
    }); /////// End Reward system

    // test token swap and liquidity feature
    describe(descTitle('Test Token Swap & Liquidity Feature'), async  () => {

        let uniswapV2RouterContract; 
        let uniswapV2FactoryContract;
        let uniswapV2FactoryAddress;
        let lpTokenAddress;
        let lpTokenContract;
        let weth;

        beforeEach(async function () {
            
            uniswapV2RouterContract = new hre.ethers.Contract(deployedContractsInfo.uniswapV2Router, uniswapV2RouterAbi, account);
            
            weth = await uniswapV2RouterContract.WETH();

            uniswapV2FactoryAddress = await uniswapV2RouterContract.factory();

            uniswapV2FactoryContract = await  new hre.ethers.Contract(uniswapV2FactoryAddress, uniswapV2FactoryAbi, account);

            lpTokenAddress = await uniswapV2FactoryContract.getPair(tokenContract.address, weth);

            ///console.log("lpTokenAddress =====>>>>", lpTokenAddress)
            lpTokenContract = await  new hre.ethers.Contract(lpTokenAddress, uniswapV2PairAbi, account);
        });


        it(`Should  match contract's uniswap router `, async () => {
            expect( (await tokenContract.uniswapRouter()) ).to.equal(uniswapV2RouterContract.address);
        });

        it(`Should  match a non zero pair router (0x0000000000000000000000000000000000000000)`, async  () => {
            expect(lpTokenAddress).to.not.equal("0x0000000000000000000000000000000000000000")
        });

        it(`Should  match contract's uniswap pair `, async () => {
            expect( (await tokenContract.uniswapPair()) ).to.equal(lpTokenAddress);
        });

    
        // lets add liquidity
        it(`Should  add liquidity`, async  () => {

            //console.log("tokenContract ==>>>", account.address)

            // approve uniswap router
           let approveTx = await tokenContract.approve(uniswapV2RouterContract.address, TOKEN_AMOUNT_FOR_LIQUIDITY_BN);

           await approveTx.wait();

            let addLiquidityTx = await uniswapV2RouterContract.addLiquidityETH(
                tokenContract.address,
                TOKEN_AMOUNT_FOR_LIQUIDITY_BN,
                0,
                0,
                account.address,
                ((+new Date())+ 360)
            ,{ value: ETH_AMOUNT_FOR_LIQUIDITY_BN })

            let txReceipt = await addLiquidityTx.wait();
            
            expect(txReceipt.status).to.equal(1)
        });


        it('Should buy tokens with ETH', async ()=> {

            let path = [weth, tokenContract.address];
            let buyAmountETH = ETH_AMOUNT_FOR_LIQUIDITY_BN.div(10);
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
            
            expect(txReceipt.status).to.equal(1)
        });

        // sell tokens to eth
        it('Should sell tokens for ETH', async ()=> {

            let path = [tokenContract.address, weth];
            let sellTokenAmount = TOKEN_AMOUNT_FOR_LIQUIDITY_BN.div(5);
            let deadline =  ((+new Date()) + 360)

            // approve uniswap router
           let approveTx = await tokenContract.approve(uniswapV2RouterContract.address, sellTokenAmount);

           await approveTx.wait();

            let sellTokenTx = await uniswapV2RouterContract.swapExactTokensForETHSupportingFeeOnTransferTokens(
                    sellTokenAmount,
                    0, // accept any amoun
                    path,
                    account.address,
                    deadline,

                    {gasLimit: 9000000, gasPrice:  ethers.utils.parseUnits('120', 'gwei')}
            );        

            let txReceipt = await sellTokenTx.wait();
            
            expect(txReceipt.status).to.equal(1)
        });


        // lets remove liquidity
        it("should remove liquidity", async () => {

           
            let amountOfLPTokensToRemove = await lpTokenContract.balanceOf(account.address);

             // remove 1/3 of the liquidity
            if(amountOfLPTokensToRemove.gt(BN.from("0"))) {
                amountOfLPTokensToRemove = amountOfLPTokensToRemove.div(2);
            }

           // approve uniswap router
           let approveTx = await lpTokenContract.approve(uniswapV2RouterContract.address, amountOfLPTokensToRemove);

           await approveTx.wait();

            //console.log("amountOfLPTokensToRemove ===>>", amountOfLPTokensToRemove.toString());

            let removeLiquidityTx = await uniswapV2RouterContract.removeLiquidityETHSupportingFeeOnTransferTokens(
                tokenContract.address,
                amountOfLPTokensToRemove,
                0,
                0,
                account.address,
                ((+new Date()) + 360)
            )

            let txReceipt = await removeLiquidityTx.wait();
                
            expect(txReceipt.status).to.equal(1)
        })

    });

}); //end describe

