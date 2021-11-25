// SPDX-License-Identifier: MIT

/**
 * PowerBull (https://powerbull.net)
 * @author PowerBull <hello@powerbull.net>
 */
 
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHoldlersRewardComputer.sol";
import "./interfaces/IPBull.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./StructsDef.sol";
//import "hardhat/console.sol";
import "./Commons.sol";


contract HoldlersRewardComputer is Ownable, Commons {
    
    using SafeMath for uint256;

    event SetRewardStartDelay(uint256 _timeInSeconds);
    event SetMinExpectedHoldlPeriod(uint256 _timeInSeconds);

    //token contract
    IPBull public tokenContract;

    // reward reflection delay, for security reason, a delay before account rewarding starts
    uint256 public rewardStartDelay = 48 hours;

    //minHoldPeriod
    // the expected minimum holding period, during this period, the reward will be released gradually till the min hold 
    // period is reached, once the min hold period is reached, full reward will be released as the reward pool increases
    uint256 public minExpectedHoldlPeriod = 60 days;


    constructor(address _tokenContract) {
        tokenContract = IPBull(_tokenContract);
    }

    modifier onlyOwnerOrTokenContract {
        require(_msgSender() == owner() || _msgSender() == address(tokenContract), "PBULL#HOLDLER_REWARD_COMPUTER: NOT_PERMITTED");
        _;
    }

    /**
     * get reward
     */
    function getReward(address _account) public view returns(uint256) {

        //lets get account balance
        uint256 accountRealBalance = tokenContract.realBalanceOf(_account);

        if(accountRealBalance == 0) {
           // console.log("HoldlersReward: Zero Balance===>>>");
            return 0;
        }
        
        //lets get account deposits info
       StructsDef.HoldlerInfo memory _holdlerInfo = tokenContract.getHoldlerInfo(_account);

        if(_holdlerInfo.initialDepositTimestamp == 0){
            return 0;
        }

        if(_holdlerInfo.initialDepositTimestamp >= block.timestamp){
            return 0;
        }

        uint256 accountHoldlPeriod = block.timestamp.sub(_holdlerInfo.initialDepositTimestamp);

        //if the deposit average is less than 1 day, give no reward
        if(accountHoldlPeriod < rewardStartDelay) {
            ///console.log("Account holdle period is less than reward start delay ==>>", rewardStartDelay, accountHoldlPeriod);
            return 0;
        } //end if 
        

        //lets check how many percent the account has holdled against the expected min holdl period
        uint256 percentHoldledAgainstExpected = (accountHoldlPeriod.mul(100)).div(minExpectedHoldlPeriod);

        //if user has held more than 100%, cap it to 100%
        if(percentHoldledAgainstExpected > 100){ percentHoldledAgainstExpected = 100; }

        //total rewards main pool
        uint256 holdlersRewardMainPool = tokenContract.holdlersRewardMainPool();

        // lets get the total rewards based on the balance
        uint256 balanceBasedReward = (accountRealBalance.mul(holdlersRewardMainPool)).div(tokenContract.totalSupply());

       // console.log("Account Holdling Time: ", accountHoldlPeriod );

       // console.log("Percent Holdled Against Expected: ", percentHoldledAgainstExpected );

       // console.log("Reward Based On Balance Only: ", balanceBasedReward);

        
         // balanceBasedReward based on holdled duration or time
         // The time based reward checks is required so that users moving balance to different addresses to take rewards will be hard
        uint256 rewardBasedOnTimeAndBalance = (percentHoldledAgainstExpected.mul(balanceBasedReward)).div(100);

        //now lets compare last released reward, if its greater than current reward 
        // then we will return 0 else we will get substration error 
        //if(_holdlerInfo.totalRewardReleased >= rewardBasedOnTimeAndBalance) {
            //console.log("_holdlerInfo.totalRewardReleased >= rewardBasedOnTimeAndBalance");
        //    return 0;
        //}

        //at here lets deduct the totalRewardsClaimed  from the current balance, this is done in instances where the 
        // user didnt use all of his or her balance, the holdling duration didnt reset, 
        // The 
        return rewardBasedOnTimeAndBalance;
        
    }//end fun 



    /**
     * setRewardStartDelay
     */
    function setRewardStartDelay(uint256 _timeInSeconds) public onlyOwnerOrTokenContract {
        rewardStartDelay = _timeInSeconds;
        emit  SetRewardStartDelay(_timeInSeconds);
    }

    /**
     * set min expected holdl period
     */
    function setMinExpectedHoldlPeriod(uint256 _timeInSeconds) public onlyOwnerOrTokenContract {

        require(_timeInSeconds > rewardStartDelay,  
            string(abi.encodePacked("PBULL#HOLDLER_REWARD_COMPUTER: _timeInSeconds cannot exceed rewardStartDelay : ", " ", bytes32(rewardStartDelay)))
        );

        minExpectedHoldlPeriod = _timeInSeconds;

        emit SetMinExpectedHoldlPeriod(_timeInSeconds);
    } //end fun 

} // contract