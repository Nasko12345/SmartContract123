
 // SPDX-License-Identifier: MIT

/**
 * PowerBull (https://powerbull.net)
 * @author  PowerBull <hello@powerbull.net>
 * @author  Zak - @zakpie (telegram)
 */

pragma solidity ^0.8.4;
pragma abicoder v2;


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libs/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./libs/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./libs/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IPBull.sol";
import "./Commons.sol";
import "./libs/_IERC20.sol";
import "hardhat/console.sol";

contract SwapEngine is Context, Ownable, Commons {

    using SafeMath for uint256;

    event Receive(address _sender, uint256 _amount);
    event AddLiquidity(uint256 _amountToken, uint256 _amountETH, address indexed liquidityOwner);
    event SwapTokenForETH(uint256 _amountToken, uint256 _receivedETHAmount, address indexed _to);
    event SetUniswapRouter(address indexed _oldRouter, address indexed _newRouter);
    event SwapETHForToken(uint256 _amountETH, uint256 _recievedTokensAmount, address indexed _to);
    event AddInitialLiquidity(address indexed _tokenContract, uint256 _amountToken, uint256 _amountETH, address indexed _liquidityOwner);

    // if add initial tx has been called already
    bool public _isAddInitialLiuqidityExecuted;

    IPBull public tokenContract;
    IUniswapV2Router02 public uniswapRouter;
    address  public uniswapPair;

    IUniswapV2Pair public uniswapPairContract;

    bytes32 public TX_TRANSFER         = keccak256(abi.encodePacked("TX_TRANSFER")); 
    bytes32 public TX_SELL             = keccak256(abi.encodePacked("TX_SELL")); 
    bytes32 public TX_BUY              = keccak256(abi.encodePacked("TX_BUY"));
    bytes32 public TX_ADD_LIQUIDITY    = keccak256(abi.encodePacked("TX_ADD_LIQUIDITY"));
    bytes32 public TX_REMOVE_LIQUIDITY = keccak256(abi.encodePacked("TX_REMOVE_LIQUIDIY"));


    constructor(address _tokenAddress, address _uniswapRouter) {

        tokenContract = IPBull(_tokenAddress);

        _setUniswapRouter(_uniswapRouter);

    } //end constructor

    receive () external payable { emit Receive(_msgSender(), msg.value ); }

    fallback () external payable {}

    // only Token modifier
    modifier onlyTokenContract {
        require(_msgSender() == address(tokenContract), "PBULL_SWAP_ENGINE: Only Token Contract Permitted");
        _;
    }//end 


    /**
     * @dev isSellTx wether the transaction is a sell tx
     * @param msgSender__ the transaction sender
     * @param _txSender the transaction sender
     * @param _txRecipient the transaction recipient
     * @param _amount the transaction amount
     */
    function getTxType(
        address  msgSender__,
        address  _txSender, 
        address  _txRecipient, 
        uint256  _amount
    ) public view onlyTokenContract returns(bytes32) {
        

       // add liquidity 
       /*if(msgSender__ == address(uniswapRouter) && // msg.sender is same as uniswap router address
           tokenContract.allowance(_txSender, address(uniswapRouter)) >= _amount && // and user has allowed 
          _txRecipient == uniswapPair // to or recipient is the uniswap pair    
        ) {
            return TX_ADD_LIQUIDITY;
        }

        // lets check remove liquidity 
        else*/
        if (msgSender__ == address(uniswapRouter) && // msg.sender is same as uniswap router address
            _txSender  ==  address(uniswapRouter) && // _from is same as uniswap router address
            _txRecipient != uniswapPair 
        ) {
            return TX_REMOVE_LIQUIDITY;
        } 

         // lets detect sell
        else if (msgSender__ == address(uniswapRouter) && // msg.sender is same as uniswap router address
            tokenContract.allowance(_txSender, address(uniswapRouter)) >= _amount && // and user has allowed 
             _txSender  !=  address(uniswapRouter) &&
            _txRecipient == uniswapPair
        ) {
            return TX_SELL;
        }
        
        // lets detect buy 
        else if (msgSender__ == uniswapPair && // msg.sender is same as uniswap pair address
            _txSender == uniswapPair  // transfer sender or _from is uniswap pair
        ) {
            return TX_BUY;
        }

        else {
            return TX_TRANSFER;
        }
    } //end get tx type

    /**
     * send weth address
     */
    function WETH() virtual public  view returns(address){
        return uniswapRouter.WETH();
    }

    /**
     * @dev set uniswap router
     * @param _uniswapRouter uniswap router contract address 
     */
    function setUniswapRouter(address _uniswapRouter)  public onlyTokenContract {
        _setUniswapRouter(_uniswapRouter);
    }

    /**
     * @dev set uniswap router
     * @param _uniswapRouter uniswap router contract address 
     */
    function _setUniswapRouter(address _uniswapRouter)  private {

        require(_uniswapRouter != address(0), "PBULL#SWAP_ENGINE: ZERO_ADDRESS");

        if(_uniswapRouter == address(uniswapRouter)){
            return;
        }

        address _oldRouter = address(uniswapRouter);
          
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);

        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());

        uniswapPair = uniswapFactory.getPair( address(tokenContract), uniswapRouter.WETH() );
        
        if(uniswapPair == address(0)) {
            // Create a uniswap pair for this new token
            uniswapPair = uniswapFactory.createPair( address(tokenContract), uniswapRouter.WETH() );
        }

        uniswapPairContract = IUniswapV2Pair(uniswapPair);

        emit SetUniswapRouter(_oldRouter, _uniswapRouter);
    } //end fun 

    /**
     * @dev get uniswap router address
     */
    function getUniswapRouter() public view returns(address) {
        return address(uniswapRouter);
    }

    /**
     * get the swap pair address
     */
    function getUniswapPair() public view returns(address) {
        return uniswapPair;
    }


    /**
    * @dev lets swap token for chain's native asset, this is bnb for bsc, eth for ethereum and ada for cardanno
    * @param _amountToken the token amount to swap to native asset
    */
    function __swapTokenForETH(uint256 _amountToken, address payable _to) private returns(uint256) {

        require(address(uniswapRouter) != address(0), "PBULL_SWAP_ENGINE#swapTokenForETH: UNISWAP_ROUTER_NOT_SET");
        require(_to != address(0), "PBULL_SWAP_ENGINE#swapTokenForETH: INVALID_TO_ADDRESS");

        address[] memory path = new address[](2);

        path[0] = address(tokenContract);
        path[1] = uniswapRouter.WETH();

        console.log("__swapTokenForETH _amountToken ===>>>>", _amountToken);

        tokenContract.approve(address(uniswapRouter), _amountToken);

        uint256  _curETHBalance = address(this).balance;

        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amountToken,
            0, // accept any amount
            path,
            address(this), // send token contract
            block.timestamp.add(360)
        );        

        uint256 returnedETHAmount;

        if(address(this).balance > _curETHBalance){
            
            returnedETHAmount = uint256(address(this).balance.sub(_curETHBalance));

            if(_to !=  address(this)) {
                require(_to.send(returnedETHAmount), "PBULL_SWAP_ENGINE#swapTokenForETH: FAILED_TO_SEND_ETH");
            }
        }

        console.log("swapEngineAddress TRANSFER_SUCCESS ======>>>>>");
        console.log( "swapEngineAddress ===>>> ", address(this) );
        console.log("__swapTokenForETH::to ===>>>> ", _to);
        console.log("__swapTokenForETH::returnedETHAmount ===>>>> ", returnedETHAmount);
        console.log("__swapTokenForETH::balance", address(this).balance );
        

        emit SwapTokenForETH(_amountToken, returnedETHAmount, _to);

        return returnedETHAmount;
    } //end


    /**
    * @dev lets swap token for chain's native asset, this is bnb for bsc, eth for ethereum and ada for cardanno
    * @param _amountToken the token amount to swap to native asset
    */
    function swapTokenForETH(uint256 _amountToken, address payable _to) public onlyTokenContract returns(uint256) {
        return __swapTokenForETH(_amountToken, _to);
    }

    
    /**
    * @dev swap ETH for tokens 
    * @param _amountETH amount to sell in ETH or native asset
    * @param _to the recipient of the tokens
    */
    function __swapETHForToken(uint256 _amountETH, address _to) private returns(uint256)  {

        address _tokenContractAddress = address(tokenContract);

        // work on the path
        address[] memory path = new address[](2);

        path[0] =  uniswapRouter.WETH();
        path[1] =  _tokenContractAddress; 
        
        
        address _tokenRecipient = _to;

        // if to is a burn or 0 address, lets get to this contract first and burn it
        if( _to == address(0) || _to == _tokenContractAddress ){
            _tokenRecipient = address(this);
        } 
        
       
        // lets get the current token balance of the _tokenRecipient 
        uint256 _recipientTokenBalance = tokenContract.balanceOf(_tokenRecipient);


        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens {value: _amountETH} (
            0, // accept any amount
            path,
            _tokenRecipient,
            block.timestamp.add(360)
        );        

        // total tokens bought
        uint256 _tokensReceived = tokenContract.balanceOf(_tokenRecipient).sub(_recipientTokenBalance);

        if(_to == address(0)){
            tokenContract.burn(_tokensReceived);
        } 
        //if was from token contract then lets send the total tokens bought
        else if( _to == _tokenContractAddress) {
            tokenContract.transfer(_tokenContractAddress, _tokensReceived);
        }

        emit SwapETHForToken(_amountETH, _tokensReceived, _to);

        return _tokensReceived;
    } //end


    /**
    * @dev swap fom tokenA to token B
    */
    function swapTokensForTokens(
        uint256     _tokenAmount, 
        address     _newTokenAddress,  
        address     _tokenRecipient
    ) public returns(uint256)  {

       // address _tokenContractAddress = address(tokenContract);

       tokenContract.approve(address(uniswapRouter), _tokenAmount);

        // work on the path
        address[] memory path = new address[](3);

        path[0] =  address(tokenContract);
        path[1] =  uniswapRouter.WETH();
        path[2] =  _newTokenAddress; 

       
        // lets get the current token balance of the _tokenRecipient 
        //uint256 _recipientTokenBalance = tokenContract.balanceOf(_tokenRecipient);

        // toTokenContract
        _IERC20 _newTokenContract = _IERC20(_newTokenAddress);

        uint256 _recipientNewTokenBalance = _newTokenContract.balanceOf(_tokenRecipient);

        // console.log("_newTokenAddress===>>", _newTokenAddress);    
        // console.log("_tokenAmount===>>", _tokenAmount);    
        //console.log("_tokenRecipient===>>", _tokenRecipient); 

        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokenAmount,
            0, // accept any amount
            path,
            _tokenRecipient,
            block.timestamp.add(360)
        );        

        // total tokens bought
        uint256 _newTokensReceieved = _newTokenContract.balanceOf(_tokenRecipient).sub(_recipientNewTokenBalance);

        //console.log("_newTokensReceieved===>>", _newTokensReceieved);    

        return _newTokensReceieved;
    } //end

    /**
    * @dev swap ETH for tokens 
    * @param _amountETH amount to sell in ETH or native asset
    * @param _to the recipient of the tokens
    */
    function swapETHForToken(uint256 _amountETH, address _to) external payable onlyTokenContract returns(uint256)  {

        require(address(uniswapRouter) != address(0), "PBULL_SWAP_ENGINE: UNISWAP_ROUTER_NOT_SET");

        require(payable(address(this)).send(msg.value), "PBULL_SWAP_ENGINE#swapETHForToken: Failed to move ETH to contract");

        return __swapETHForToken(_amountETH, _to);
    }

    
    /**
     * @dev add liquidity to the swap
     * @param _amountToken token amount to add
     * @param _amountETH  native asset example: bnb to add to token as pair for liquidity
     */
    function __addLiquidity(uint256 _amountToken, uint256 _amountETH) internal returns(uint256, uint256, uint256) {

        require( address(this).balance >= _amountETH, "PBULL_SWAP_ENGINE#ADD_LIQUIDITY: INSUFFICIENT_ETH_BALANCE");

        tokenContract.approve(address(uniswapRouter), _amountToken);


        // add the liquidity
        (uint256 amountTokenAdded, uint256 amountETHAdded, uint256 liquidityAdded) = uniswapRouter.addLiquidityETH { value: _amountETH } (
            address(tokenContract), //token contract address
            _amountToken, // token amount to add liquidity
            0, //amountTokenMin 
            0, //amountETHMin
            tokenContract.autoLiquidityOwner(), //owner of the liquidity
            block.timestamp.add(360) //deadline
        );


        //lets check if we have remainig eth Balance
        if(_amountETH > amountETHAdded){

            uint256 remainingETH = _amountETH.sub(amountETHAdded);

            if( address(this).balance >= remainingETH) {

                //remaining balance after the add liquidity 
                (bool tSuccess, ) = payable(address(tokenContract)).call{value: remainingETH}("");
                
                require(tSuccess, "PBULL_SWAP_ENGINE#ADD_LIQUIDITY: FAILED_TO_TRANSFER_ETH_BALANCE");
            }

        } //end return remaining bnb

        //lets return remaining tokens
        if(_amountToken > amountTokenAdded) {

            uint256 remainingToken = _amountToken.sub(amountTokenAdded);

            if( tokenContract.realBalanceOf(address(this)) >= remainingToken ) {
                bool tokenTransferSuccess = tokenContract.transfer( address(this), remainingToken );
                require(tokenTransferSuccess, "PBULL_SWAP_ENGINE#ADD_LIQUIDITY: FAILED_TO_TRANSFER_TOKEN_BALANCE");
            } //end if

        } //end if 


        emit AddLiquidity(_amountToken, _amountETH, tokenContract.autoLiquidityOwner());

        return (amountTokenAdded, amountETHAdded, liquidityAdded);
    } //end add liquidity


    /**
     * @dev add liquidity to the swap
     * @param _amountToken token amount to add
     * @param _amountETH  native asset example: bnb to add to token as pair for liquidity
     */
    function addLiquidity(uint256 _amountToken, uint256 _amountETH) external payable onlyTokenContract returns(uint256, uint256, uint256) {

        require(address(uniswapRouter) != address(0), "PBULL_SWAP_ENGINE: UNISWAP_ROUTER_NOT_SET");

        require(msg.value >= _amountETH, "PBULL_SWAP_ENGINE: msg.value not equal to _amountETH");

        require(payable(address(this)).send(msg.value), "PBULL_SWAP_ENGINE#addLquidity: Failed to move ETH to contract");

        return __addLiquidity(_amountToken, _amountETH);
    }

    /**
     * @dev swap and add liquidity
     * @param _amountToken amount of tokens to swap and liquidity 
     */
    function swapAndLiquidify(uint256 _amountToken)  public payable onlyTokenContract  returns(uint256, uint256, uint256) {
        
        require( address(uniswapRouter) != address(0), "PBULL_SWAP_ENGINE#swapAndLiquidify: UNISWAP_ROUTER_NOT_SET");

        // lets check if we have to that amount else abort operation
        require(_amountToken > 0 && tokenContract.realBalanceOf(address(this)) >= _amountToken, "PBULL_SWAP_ENGINE#swapAndLiquidify: INSUFFICIENT_TOKEN_BALANCE");

        uint256 _amountTokenHalf = _amountToken.div(2);
        
        //lets swap to get some base asset
        uint256 swappedETHAmount = __swapTokenForETH( _amountTokenHalf, payable(address(this)) );

        //console.log("swapAndLiquidify::swappedETHAmount====>>> ", swappedETHAmount);

        require( address(this).balance  >=  swappedETHAmount, "PBULL_SWAP_ENGINE#swapAndLiquidify: SWAPPED_ETH_AMOUNT_MORE_EXCEEDS_BALANCE");

        return __addLiquidity(_amountTokenHalf, swappedETHAmount);
    } //end add liquidity


    /**
     * @dev add Initial Liquidity to swap exchange
     * @param _amountToken the token amount 
     */
    function addInitialLiquidity(uint256 _amountToken ) external payable onlyOwner  {

        require(address(uniswapRouter) != address(0), "PBULL_SWAP_ENGINE#addInitialLiquidity: UNISWAP_ROUTER_NOT_SET");

        require(!_isAddInitialLiuqidityExecuted,"PBULL_SWAP_ENGINE#addInitialLiquidity: function already called");
        require(msg.value > 0, "PBULL_SWAP_ENGINE#addInitialLiquidity: msg.value must exceed 0");
        require(_amountToken > 0, "PBULL_SWAP_ENGINE#addInitialLiquidity: _amountToken must exceed  0");

        require(payable(address(this)).send(msg.value), "PBULL_SWAP_ENGINE#addInitialLiquidity: Failed to move ETH to contract");

         _isAddInitialLiuqidityExecuted = true;

        tokenContract.transferFrom(_msgSender(), address(this), _amountToken);

        tokenContract.approve(address(uniswapRouter), _amountToken );

        //console.log("SWAPENGINE BALANCE ====>>> ", tokenContract.balanceOf(address(this)));

        // add the liquidity
        uniswapRouter.addLiquidityETH { value: msg.value } (
            address(tokenContract), //token contract address
            _amountToken, // token amount we wish to provide liquidity for
            _amountToken, //amountTokenMin 
            msg.value, //amountETHMin
            _msgSender(), 
            block.timestamp.add(360) //deadline
        );

        emit AddInitialLiquidity(address(tokenContract), _amountToken, msg.value, _msgSender());
    } //end add liquidity


}