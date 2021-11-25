// SPDX-License-Identifier: MIT

/**
 * PowerBull (https://powerbull.net)
 * @author PowerBull <hello@powerbull.net>
 */
 
pragma solidity ^0.8.4;
pragma abicoder v2;

abstract contract ISwapEngine {

    bytes32 public TX_TRANSFER;
    bytes32 public TX_SELL;
    bytes32 public TX_BUY;
    bytes32 public TX_ADD_LIQUIDITY;
    bytes32 public TX_REMOVE_LIQUIDITY;

    function swapTokenForETH(uint256 _amountToken, address payable _to) virtual external payable returns(uint256);
    
    function addLiquidity(uint256 _amountToken, uint256 _amountETH) virtual external payable  returns(uint256, uint256, uint256);
    function swapAndLiquidify(uint256 _amountToken) virtual external payable returns(uint256, uint256, uint256);
    function addInitialLiquidity(uint256 _amountToken ) virtual external;
    function setUniswapRouter(address _uniswapRoter) virtual public;
    
    function getUniswapPair() virtual public view returns(address);
    function getUniswapRouter() virtual public view returns(address);

    function swapETHForToken(uint256 _amountETH, address _to) virtual public payable returns(uint256);
    
    function swapTokensForTokens(
        uint256 _tokenAmount, 
        address _toTokenAddress,  
        address _recipient
    ) virtual public payable returns(uint256);
    

    function getTxType(address msgSender__, address _from, address _to, uint256  _amount) virtual public  view returns(bytes32);

    function WETH() virtual public  view returns(address);

}