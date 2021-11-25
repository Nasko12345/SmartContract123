// SPDX-License-Identifier: MIT

/**
 * PowerBull (https://powerbull.net)
 * @author PowerBull <hello@powerbull.net>
 */

pragma solidity ^0.8.4;
pragma abicoder v2;

contract StructsDef {
    
    struct HoldlerInfo {
        uint256 depositCount;
        uint256 initialDepositTimestamp; // initial deposit time stamp
        uint256 totalRewardReleased;
    }

    struct AccountThrottleInfo {
        uint256 txAmountLimitPercent;
        uint256 timeIntervalPerTx;
        uint256 lastTxTime;
    }

    struct FactionInfo {
        address  _address;
        uint256  _totalMembers;
        uint256  _totalPoint;
        uint256  _createdAt;
        uint256  _updatedAt;
        uint8    status; 
    }

}