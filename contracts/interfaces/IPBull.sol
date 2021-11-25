// SPDX-License-Identifier: MIT

/**
 * PowerBull (https://powerbull.net)
 * @author PowerBull <hello@powerbull.net>
 */
 
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../StructsDef.sol";
import "../libs/_IERC20.sol";

abstract contract IPBull is _IERC20 {

    address  public autoLiquidityOwner;

    uint256  public autoLiquidityPool;
    uint256  public autoBurnPool;
    uint256  public holdlersRewardMainPool;
    uint256  public holdlersRewardReservedPool;
    uint256  public liquidityProvidersIncentivePool;

    function burn( uint256 amount) virtual public;
    function getHoldlerInfo(address _account) virtual public view returns (StructsDef.HoldlerInfo memory);
    function realBalanceOf(address _account) virtual  public view returns(uint256);
}