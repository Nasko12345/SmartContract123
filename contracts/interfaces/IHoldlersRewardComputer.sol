// SPDX-License-Identifier: MIT

/**
 * PowerBull (https://powerbull.net)
 * @author PowerBull <hello@powerbull.net>
 */
 
pragma solidity ^0.8.4;
pragma abicoder v2;


abstract contract IHoldlersRewardComputer {
    
    uint256 public rewardStartDelay;
    uint256 public minExpectedHoldlPeriod;

    function getReward(address _account) virtual public view returns(uint256);
    function setRewardStartDelay(uint256 _timeInSeconds) virtual public;
    function setMinExpectedHoldlPeriod(uint256 _timeInSeconds) virtual public;
}