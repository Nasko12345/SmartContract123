// SPDX-License-Identifier: MIT

/**
 * PowerBull (https://powerbull.net)
 * @author PowerBull <hello@powerbull.net>
 */
 
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./libs/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHoldlersRewardComputer.sol";
import "./StructsDef.sol";
import "./Commons.sol";
//import "./interfaces/ISwapEngine.sol";
import "./libs/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./libs/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./libs/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "hardhat/console.sol";


contract PBull is   Context, Ownable, ERC20, Commons {

    event Receive(address _sender, uint256 _amount);


    using SafeMath for uint256;

    string  private constant  _tokenName                          =    "Luckie Jodjie 4";
    string  private constant  _tokenSymbol                        =    "LLJ4";
    uint8   private constant  _tokenDecimals                      =     18;
    uint256 private constant  _tokenSupply                        =     26_000_000  * (10 ** _tokenDecimals); // 25m

    /////////////////////// This will deposit _initialPercentageOfTokensForRewardPool into the reward pool for the users to split over time /////////////
    /////////////////////// Note this is a one time during contract initialization ///////////////////////////////////////////////////////
    uint256 public constant  _initialPercentOfTokensForHoldlersRewardPool =  100; /// 1% of total supply

    // reward token 
    address rewardTokenAddress     =     0x6B175474E89094C44Da98b954EedeAC495271d0F; // wbnb token                 
    
    ERC20 rewardTokenContract = ERC20(rewardTokenAddress);

    // reward limit before release 
    uint256 public minimumRewardBeforeRelease = 1;

    // tax 
    uint256 public  marketingFee      =     100; // 100 = 1%
    uint256 public  devFee            =     100; // 100 = 1%

    // set the dev and marketing wallet here, default is deployer
    address payable devAndMarketingWallet;
    
   

    bool public isAutoLiquidityEnabled                             =  true;
    bool public isHoldlersRewardEnabled                            =  true; 
    bool public isBuyBackEnabled                                   =  true;
    bool public isSellTaxEnabled                                   =  true; 
    bool public isMarketingFeeEnabled                              =  true;  
    bool public isDevFeeEnabled                                    =  true;     


    //using basis point, multiple number by 100  
    uint256  public  holdlersRewardFee                               =  100;     // 1% for holdlers reward pool
    uint256  public  autoLiquidityFee                                =  100;     // 1% fee charged on tx for adding liquidity pool
    uint256  public  buyBackFee                                      =  100;     // 1% will be used for buyback
    uint256  public  sellTaxFee                                      =  50;    //  1% a sell tax fee, which applies to sell only
    

    //buyback 
    uint256 public minAmountBeforeSellingTokenForBuyBack             =  50_000 * (10 ** _tokenDecimals); 
    uint256 public minAmountBeforeSellingETHForBuyBack               =  1 ether;
    uint256 public buyBackETHAmountSplitDivisor                      =  100;
    
    uint256 public buyBackTokenPool;
    uint256 public buyBackETHPool;
    
    uint256 public totalBuyBacksAmountInTokens;
    uint256 public totalBuyBacksAmountInETH;

    // funds pool
    uint256  public autoLiquidityPool;
    //uint256  public autoBurnPool;
    uint256  public liquidityProvidersIncentivePool;

    //////////////////////////////// START REWARD POOL ///////////////////////////

    // token pool to sell or credit to the main pools
    uint256  public pendingRewardTokenPool;

    uint256  public holdlersRewardMainPool;
    
    // reward pool reserve  used in replenishing the main pool any time someone withdraw else
    // the others holdlers will see a reduction  in rewards
    uint256  public holdlersRewardReservedPool;

    ////// percentage of reward we should allocate to  reserve pool
    uint256  public percentageShareOfHoldlersRewardsForReservedPool                       =  3000; /// 30% in basis point system

    // The minimum amount required to keep in the holdlersRewardsReservePool
    // this means if the reserve pool goes less than minPercentOfReserveRewardToMainRewardPool  of the main pool, use 
    // next collected fee for rewards into the reserve pool till its greater than minPercentOfReserveRewardToMainRewardPool
    uint256 public minPercentageOfholdlersRewardReservedPoolToMainPool                    =  3000; /// 30% in basis point system



    ///////////////////////////////// END  REWARD POOL ////////////////////////////

    // liquidity owner
    address public autoLiquidityOwner;

    //minimum amount before adding auto liquidity
    uint256 public minAmountBeforeAutoLiquidity                             =   60_000 * (10 ** _tokenDecimals);    

    // minimum amount before auto burn
    uint256 public minAmountBeforeAutoBurn                                  =   500_000 * (10 ** _tokenDecimals);    

    bytes32 public  txTypeForMaxTxAmountLimit                               =   keccak256(abi.encodePacked("TX_SELL")); 
    ///////////////////// START  MAPS ///////////////////////

    //accounts excluded from fees
    mapping(address => bool) public excludedFromFees;
    mapping(address => bool) public excludedFromRewards;
    mapping(address => bool) public excludedFromPausable;

    // permit nonces
    mapping(address => uint) public nonces;
    
    //acounts deposit info mapping keeping all user info
    // address => initial Deposit timestamp
    mapping(address => StructsDef.HoldlerInfo) private holdlersInfo;

    ////////////////// END MAPS ////////////////

    uint256 public totalRewardsTaken;

    bool isSwapAndLiquidifyLocked;

    // extending erc20 to support permit 
    bytes32 public DOMAIN_SEPARATOR;
    
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;


    // timestamp the contract was deployed
    uint256 public immutable deploymentTimestamp;

    // isPaused 
    bool public isPaused; // if contract is paused

    // total token holders
    uint256 public totalTokenHolders;

    // external contracts 
    IHoldlersRewardComputer   public    holdlersRewardComputer;
   // ISwapEngine               public    swapEngine;
    //ITeams                    public    teamsContract;


    uint256                   public    totalLiquidityAdded;

    //////// WETHER the token is initialized or not /////////////

    bool public initialized;

    // token contract 
    address public immutable _tokenAddress;


    IUniswapV2Router02 public uniswapRouter;
    address  public uniswapPair;

    IUniswapV2Pair public uniswapPairContract;

    address WETH;

    bytes32 public TX_TRANSFER         = keccak256(abi.encodePacked("TX_TRANSFER")); 
    bytes32 public TX_SELL             = keccak256(abi.encodePacked("TX_SELL")); 
    bytes32 public TX_BUY              = keccak256(abi.encodePacked("TX_BUY"));
    bytes32 public TX_ADD_LIQUIDITY    = keccak256(abi.encodePacked("TX_ADD_LIQUIDITY"));
    bytes32 public TX_REMOVE_LIQUIDITY = keccak256(abi.encodePacked("TX_REMOVE_LIQUIDIY"));

    address public burnAddress = 0x000000000000000000000000000000000000dEaD;


    ///////// Dev and marketing wallet /////////////////

    uint256  public devAndMarketingFundPool;

    // constructor 
    constructor() ERC20 (_tokenName,_tokenSymbol, _tokenDecimals) {

        // initialize token address
        _tokenAddress = address(this);

        // mint 
        _mint(_msgSender(), _tokenSupply);


        if(devAndMarketingWallet == address(0)) {
            // set dev and marketing wallet to deployer
            devAndMarketingWallet = payable(_msgSender());
        }

        //excludes for 
        excludedFromFees[address(this)]                 =       true;
        excludedFromRewards[address(this)]              =       true;
        excludedFromPausable[address(this)]             =       true;

        //excludes for owner
        excludedFromFees[_msgSender()]                  =       true;
        excludedFromPausable[_msgSender()]              =       true;
        excludedFromPausable[_msgSender()]              =       true;


        // set auto liquidity owner
        autoLiquidityOwner                              =       _msgSender();

        // set the deploymenet time
        deploymentTimestamp                             =       block.timestamp;

        // permit domain separator
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name())),
                keccak256(bytes('1')),
                getChainId(),
                address(this)
            )
        );


        //set minimum reward before release
        if(rewardTokenAddress == address(0) || rewardTokenAddress == address(this)){
            minimumRewardBeforeRelease = minimumRewardBeforeRelease * (10 ** _tokenDecimals);
        } else {
            minimumRewardBeforeRelease = minimumRewardBeforeRelease * (10 ** rewardTokenContract.decimals());
        }

    } //end constructor 
    

    /**
     * initialize the project
     * @param  _uniswapRouter the uniswap router
     * @param  _holdlersRewardComputer the holdlers reward computer
     */
    function _initializeContract (
        address  _uniswapRouter, 
        address  _holdlersRewardComputer
    )  public onlyOwner {
        
        require(!initialized, "PBULL: ALREADY_INITIALIZED");
        require(_holdlersRewardComputer != address(0), "PBULL: INVALID_HOLDLERS_REWARD_COMPUTER_CONTRACT");

        // this will update the uniswap router again
        setUniswapRouter(_uniswapRouter);

        holdlersRewardComputer = IHoldlersRewardComputer(_holdlersRewardComputer);

        if(rewardTokenAddress == address(this)){
            // lets deposit holdlers reward pool initial funds     
            processHoldlersRewardPoolInitialFunds();
        }

        initialized = true;

    }   //end intialize


    /**
    * @dev processRewardPool Initial Funds 
    */
    function processHoldlersRewardPoolInitialFunds() private {

        require(!initialized, "PBULL: ALREADY_INITIALIZED");

         // if no tokens were assign to the rewards dont process
        if(_initialPercentOfTokensForHoldlersRewardPool == 0){
            return;
        }
        
        //let get the rewardPool initial funds 
        uint256 rewardPoolInitialFunds = percentToAmount(_initialPercentOfTokensForHoldlersRewardPool, totalSupply());

        //first of all lets move funds to the contract 
        internalTransfer(_msgSender(), _tokenAddress, rewardPoolInitialFunds,"REWARD_POOL_INITIAL_FUNDS_TRANSFER_ERROR", true);

        uint256 rewardsPoolsFundSplit = rewardPoolInitialFunds.sub(2);

         // lets split them 50% 50% into the rewardmainPool and rewards Reserved pool
         holdlersRewardMainPool = holdlersRewardMainPool.add(rewardsPoolsFundSplit);

         // lets put 50% into the reserve pool
         holdlersRewardReservedPool = holdlersRewardReservedPool.add(rewardsPoolsFundSplit);
    } //end function


    receive () external payable { emit Receive(_msgSender(), msg.value ); }

    fallback () external payable {}

    /**
     * lock swap or add liquidity  activity
     */
    modifier lockSwapAndLiquidify {
        isSwapAndLiquidifyLocked = true;
        _;
        isSwapAndLiquidifyLocked = false;
    }

    /**
     * get chain Id 
     */
    function getChainId() public view returns (uint256) {
        uint256 id;
        assembly { id := chainid() }
        return id;
    }

    /**
     * @dev erc20 permit 
     */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'PBULL: PERMIT_EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'PBULL: PERMIT_INVALID_SIGNATURE');
        _approve(owner, spender, value);
    } 


    /**
     * realBalanceOf - get account real balance
     */
    function realBalanceOf(address _account)  public view returns(uint256) {
        return super.balanceOf(_account);
    }

    /**
     * override balanceOf - This now returns user balance + reward
     **/
    function balanceOf(address _account) override public view returns(uint256) {

        uint256 accountBalance = super.balanceOf(_account);

        if(!( rewardTokenAddress == address(0) || rewardTokenAddress == address(this) )) {
            return accountBalance;
        }

        if(accountBalance <= 0){
            accountBalance = 0;
        }
        
        uint256 reward = getReward(_account);

        if(reward <= 0){
            return accountBalance;
        }

        return (accountBalance.add(reward));
    } //end fun


    ////////////////////////// HOLDERS REWARD COMPUTER FUNCTIONS ///////////////////
    /**
     * get an account reward 
     * @param _account the account to get the reward info
     */
    function getReward(address _account) public view returns(uint256) {
        
       
        if(!isHoldlersRewardEnabled || excludedFromRewards[_account]) {
            return 0;
        }

        uint256 reward = holdlersRewardComputer.getReward(_account);

        if(reward <= 0){
            return 0;
        }

        return reward;
        
    }//end get reward

    /**
     * @dev the delay in seconds before a holdlers starts seeing rewards after initial deposit
     * @return time in seconds 
     */
    function rewardStartDelay() public view returns(uint256) {
       return holdlersRewardComputer.rewardStartDelay();
    } 

    /**
     * @dev set the number of delay in time before a reward starts showing up
     * @param _delayInSeconds the delay in seconds
     */
    function setRewardStartDelay(uint256 _delayInSeconds) public onlyOwner {
        holdlersRewardComputer.setRewardStartDelay(_delayInSeconds);
    } 


    /**
     * @dev the minimum expected holdl period 
     * @return time in seconds 
     */
     function minExpectedHoldlPeriod() public view returns (uint256) {
        return holdlersRewardComputer.minExpectedHoldlPeriod();
     }

    /**
     * @dev set the minimum expected holdl period 
     * @param _timeInSeconds time in seconds 
     */
     function setMinExpectedHoldlPeriod(uint256 _timeInSeconds) public onlyOwner  {
         holdlersRewardComputer.setMinExpectedHoldlPeriod(_timeInSeconds);
     }


    /**
     * minimum reward before release
     */
    function setMinimumRewardBeforeRelease(uint256 _amountValue) public onlyOwner  {
        minimumRewardBeforeRelease = _amountValue;
     }


    /**
     * enableMarketingFee
     */
    function enableMarketingFee(bool _option) public onlyOwner  {
        isMarketingFeeEnabled = _option;
    }

    /**
     * setMarketingWallet
     */
    function setMarketingFee(uint256 _value) public onlyOwner  {
        marketingFee = _value;
    }

    /**
     * setDevWallet
     */
    function setDevFee(uint256 _value) public onlyOwner  {
        devFee = _value;
    }

    /**
     * enableMarketingFee
     */
    function enableDevFee(bool _option) public onlyOwner  {
        isDevFeeEnabled = _option;
    }


    /**
     * setMarketingWallet
     */
    function setDevAndMarketingWallet(address payable _wallet) public onlyOwner  {
        devAndMarketingWallet = _wallet;
    }

    ////////////////////////// END HOLDERS REWARD COMPUTER FUNCTIONS ///////////////////

    /**
     * @dev get initial deposit time
     * @param _account the account to get the info
     * @return account tx info
     */
    function getHoldlerInfo(address _account) public view returns (StructsDef.HoldlerInfo memory) {
        return holdlersInfo[_account];
    }



    //////////////////////// START OPTION SETTER /////////////////

    /**
     * @dev set auto liquidity owner address
     * @param _account the EOS address for system liquidity
     */
    function setAutoLiquidityOwner(address _account) public onlyOwner {
         autoLiquidityOwner = _account;
    }




    /**
     * @dev enable or disable auto buyback 
     * @param _option true to enable, false to disable
     */
    function enableBuyBack(bool _option) public onlyOwner {
        isBuyBackEnabled = _option;
    }

    /**
     * @dev enable or disable auto liquidity 
     * @param _option true to enable, false to disable
     */
    function enableAutoLiquidity(bool _option) public onlyOwner {
        isAutoLiquidityEnabled = _option;
    }


    /**
     * @dev enable or disable holdlers reward
     * @param _option true to enable, false to disable
     */
    function enableHoldlersReward(bool _option) public onlyOwner {
        isHoldlersRewardEnabled = _option;
    }


    /**
     * @dev enable or disable sell Tax
     * @param _option true to enable, false to disable
     */
    function enableSellTax(bool _option) public onlyOwner {
        isSellTaxEnabled = _option;
    }

    /**
     * @dev enable or disable all fees 
     * @param _option true to enable, false to disable
     */
    function enableAllFees(bool _option) public onlyOwner {
        isBuyBackEnabled                        = _option;
        isAutoLiquidityEnabled                  = _option;
        isHoldlersRewardEnabled                 = _option;
        isSellTaxEnabled                        = _option;
        isDevFeeEnabled                         = _option;
        isMarketingFeeEnabled                   = _option;
    }

    
    //////////////////// END OPTION SETTER //////////


   
    ///////////////////// START  SETTER ///////////////
     

    /**
     * @dev set the auto buyback fee
     * @param _valueBps the fee value in basis point system
     */
    function setBuyBackFee(uint256 _valueBps) public onlyOwner { 
        buyBackFee = _valueBps;
    }

    /**
     * @dev set holdlers reward fee
     * @param _valueBps the fee value in basis point system
     */
    function setHoldlersRewardFee(uint256 _valueBps) public onlyOwner { 
        holdlersRewardFee = _valueBps;
    }


    /**
     * @dev auto liquidity fee 
     * @param _valueBps the fee value in basis point system
     */
    function setAutoLiquidityFee(uint256 _valueBps) public onlyOwner { 
        autoLiquidityFee = _valueBps;
    }


    /**
     * @dev set Sell Tax Fee
     * @param _valueBps the fee value in basis point system
     */
    function setSellTaxFee(uint256 _valueBps) public onlyOwner { 
        sellTaxFee = _valueBps;
    }



    //////////////////////////// END  SETTER /////////////////


    /**
     * @dev get total fee 
     * @return the total fee in uint256 number
     */
    function getTotalFee() public view returns(uint256){

        uint256 fee = 0;

        if(isBuyBackEnabled){ fee += buyBackFee; }
        if(isAutoLiquidityEnabled){ fee += autoLiquidityFee; }
        if(isHoldlersRewardEnabled){ fee += holdlersRewardFee; }
        if(isSellTaxEnabled) { fee += sellTaxFee; }
        if(isDevFeeEnabled) { fee += devFee; }
        if(isMarketingFeeEnabled) { fee += marketingFee; }

        return fee;
    } //end function


    /**
     * @dev set holders reward computer contract called HoldlEffect
     * @param _contractAddress the contract address
     */
    function setHoldlersRewardComputer(address _contractAddress) public onlyOwner {
        require(_contractAddress != address(0),"PBULL: SET_HOLDLERS_REWARD_COMPUTER_INVALID_ADDRESS");
        holdlersRewardComputer = IHoldlersRewardComputer(_contractAddress);
    }

     /**
     * @dev set uniswap router address
     * @param _uniswapRouter uniswap router contract address
     */
    function setUniswapRouter(address _uniswapRouter) public onlyOwner {
        
        require(_uniswapRouter != address(0), "PBULL#SWAP_ENGINE: ZERO_ADDRESS");

        if(_uniswapRouter == address(uniswapRouter)){
            return;
        }

        address _oldRouter = address(uniswapRouter);
          
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);

        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());

        WETH = uniswapRouter.WETH();

        uniswapPair = uniswapFactory.getPair( address(this), WETH);
        
        if(uniswapPair == address(0)) {
            // Create a uniswap pair for this new token
            uniswapPair = uniswapFactory.createPair( address(this), WETH);
        }

        uniswapPairContract = IUniswapV2Pair(uniswapPair);

        // lets disable rewards for uniswap pair and router
        excludedFromRewards[_uniswapRouter] = true;
        excludedFromRewards[uniswapPair] = true;
    } 


    ////////////////// START EXCLUDES ////////////////

    /**
     * @dev exclude or include  an account from paying fees
     * @param _option true to exclude, false to include
     */
    function excludeFromFees(address _account, bool _option) public onlyOwner {
        excludedFromFees[_account] = _option;
    }

    /**
     * @dev exclude or include  an account from getting rewards
     * @param _option true to exclude, false to include
     */
    function excludeFromRewards(address _account, bool _option) public onlyOwner {
        excludedFromRewards[_account] = _option;
    }




    /**
     * @dev exclude from paused
     * @param _option true to exclude, false to include
     */
    function excludeFromPausable(address _account, bool _option) public onlyOwner {
        excludedFromPausable[_account] = _option;
    }

    //////////////////// END EXCLUDES ///////////////////


    /**
     * @dev minimum amount before adding auto liquidity
     * @param _amount the amount of tokens before executing auto liquidity
     */
    function setMinAmountBeforeAutoLiquidity(uint256 _amount) public onlyOwner {
        minAmountBeforeAutoLiquidity = _amount;
    }

    /**
     * @dev set min amount before auto burning
     * @param _amount the minimum amount when reached we should auto burn
     */
    function setMinAmountBeforeAutoBurn(uint256 _amount) public onlyOwner {
        minAmountBeforeAutoBurn = _amount;
    }


    /**
     * @dev set min amount before selling tokens for buyback
     * @param _amount the minimum amount 
     */
    function setMinAmountBeforeSellingETHForBuyBack(uint256 _amount) public onlyOwner {
        minAmountBeforeSellingETHForBuyBack = _amount;
    }

    /**
     * @dev set min amount before selling tokens for buyback
     * @param _amount the minimum amount 
     */
    function setMinAmountBeforeSellingTokenForBuyBack(uint256 _amount) public onlyOwner {
        minAmountBeforeSellingTokenForBuyBack = _amount;
    }

    /**
     * @dev set the buyback eth divisor
     * @param _value the no of divisor
     */
    function setBuyBackETHAmountSplitDivisor(uint256 _value) public onlyOwner {
        buyBackETHAmountSplitDivisor = _value;
    }

    /**
     * set the min amount of reserved rewards pool to main rewards pool
     * @param _valueBps the value in basis point system
     */
    function setMinPercentageOfholdlersRewardReservedPoolToMainPool(uint256 _valueBps) public onlyOwner {
        minPercentageOfholdlersRewardReservedPoolToMainPool  = _valueBps;
    }//end fun 


    /**  
     * set the the percentage share of holdlers rewards to be saved into the reserved pool
     * @param _valueBps the value in basis point system
     */
    function setPercentageShareOfHoldlersRewardsForReservedPool(uint256 _valueBps) public onlyOwner {
        percentageShareOfHoldlersRewardsForReservedPool = _valueBps;
    }//end fun 


    ////////// START SWAP AND LIQUIDITY ///////////////

    /**
     * @dev pause contract 
     */
    function pauseContract(bool _option) public onlyOwner {
        isPaused = _option;
    }


    /**
    * @dev lets swap token for chain's native asset, this is bnb for bsc, eth for ethereum and ada for cardanno
    * @param _amountToken the token amount to swap to native asset
    */
    function __swapTokenForETH(uint256 _amountToken, address payable _to) private lockSwapAndLiquidify returns(uint256) {

        if( _amountToken > realBalanceOf(_tokenAddress) ) {
            return 0;
        }

        require(_to != address(0), "PBULL_SWAP_ENGINE#swapTokenForETH: INVALID_TO_ADDRESS");

        address[] memory path = new address[](2);

        path[0] = address(this);
        path[1] = WETH;

        super._approve(address(this), address(uniswapRouter), _amountToken);

        uint256  _curETHBalance = address(this).balance;

        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amountToken,
            0, // accept any amount
            path,
            _to, // send token contract
            block.timestamp.add(360)
        );        

        uint256 returnedETHAmount = uint256(address(this).balance.sub(_curETHBalance));
        
        return returnedETHAmount;
    } //end


    /**
    * @dev lets swap token for chain's native asset 
    * this is bnb for bsc, eth for ethereum and ada for cardanno
    */
    function __swapTokensForRewardTokens(uint256 _tokenAmount) private lockSwapAndLiquidify returns(uint256) 
    {   

        address tokenAddress = address(this);

        if( _tokenAmount == 0 || _tokenAmount > realBalanceOf(tokenAddress) ) {
            return 0;
        }

        super._approve(tokenAddress, address(uniswapRouter), _tokenAmount);

        // work on the path
        address[] memory path = new address[](3);

        path[0] =  tokenAddress;
        path[1] =  WETH;
        path[2] =  rewardTokenAddress; 


        uint256 _balanceSnapshot = rewardTokenContract.balanceOf(tokenAddress);

         console.log("_balanceSnapshot===>>", _balanceSnapshot);    
         console.log("_tokenAmount===>>", _tokenAmount);    
        //console.log("_tokenRecipient===>>", _tokenRecipient); 

        uniswapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokenAmount,
            0, // accept any amount
            path,
            tokenAddress,
            block.timestamp.add(360)
        );        

        // total tokens bought
        return rewardTokenContract.balanceOf(tokenAddress).sub(_balanceSnapshot);
    }


    /**
     * @dev swap and add liquidity
     * @param _amountToken amount of tokens to swap and liquidity 
     */
    function swapAndLiquidify(uint256 _amountToken) private lockSwapAndLiquidify {
        
        if( _amountToken > realBalanceOf(address(this)) ) {
            return;
        }
        
        uint256 _amountTokenHalf = _amountToken.div(2);
        
        //lets swap to get some base asset
        uint256 _amountETH = __swapTokenForETH( _amountTokenHalf, payable(address(this)) );

        if(_amountETH == 0){
            return;
        }

        super._approve(address(this), address(uniswapRouter), _amountToken);

        // add the liquidity
        uniswapRouter.addLiquidityETH { value: _amountETH } (
            address(this), //token contract address
            _amountToken, // token amount to add liquidity
            0, //amountTokenMin 
            0, //amountETHMin
            autoLiquidityOwner, //owner of the liquidity
            block.timestamp.add(360) //deadline
        );

     } //end function


    /**
    * @dev swap ETH for tokens 
    * @param _amountETH amount to sell in ETH or native asset
    * @param _to the recipient of the tokens
    */
    function __swapETHForToken(
        uint256 _amountETH, 
        ERC20 _tokenContract, 
        address _to
    ) private lockSwapAndLiquidify returns(uint256)  {

        address tokenAddress = address(_tokenContract);

        // work on the path
        address[] memory path = new address[](2);

        path[0] =  WETH;
        path[1] =  tokenAddress; 

        // lets get the current token balance of the _tokenRecipient 
        uint256 _toBalance = _tokenContract.balanceOf(_to);

        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens {value: _amountETH} (
            0, // accept any amount
            path,
            _to,
            block.timestamp.add(360)
        );    

        uint256 newBalance = _tokenContract.balanceOf(_to);

        if(newBalance <= _toBalance){
            return 0;
        }

        // total tokens bought
        return newBalance.sub(_toBalance);

    } //end


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
    ) private view  returns(bytes32) {
        
       
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
            allowance(_txSender, address(uniswapRouter)) >= _amount && // and user has allowed 
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
     * override _transfer
     * @param sender the token sender
     * @param recipient the token recipient
     * @param amount the number of tokens to transfer
     */
     function _transfer(address sender, address recipient, uint256 amount) override internal virtual {

        // check if the contract has been initialized
        require(initialized, "PBULL: CONTRACT_NOT_INITIALIZED");        
        require(amount > 0, "PBULL: ZERO_AMOUNT");
        require(balanceOf(sender) >= amount, "PBULL: INSUFFICIENT_BALANCE");
        require(sender != address(0), "PBULL: INVALID_SENDER");
       
        // lets check if paused or not
        if(isPaused) {
            if( !excludedFromPausable[sender] ) {
                revert("PBULL: CONTRACT_PAUSED");
            }
        }

        // before we process anything, lets release senders reward
        releaseAccountReward(sender);

        // lets check if we have gain +1 user
        // before transfer if recipient has no tokens, means he or she isnt a token holder
        if(_balances[recipient] == 0) {
            totalTokenHolders = totalTokenHolders.add(1);
        } //end if


        //at this point lets get transaction type
        bytes32 txType = getTxType(_msgSender(), sender, recipient, amount);

        uint256 amountMinusFees = _processBeforeTransfer(sender, recipient, amount, txType);

        //make transfer
        internalTransfer(sender, recipient, amountMinusFees,  "PBULL: TRANSFER_AMOUNT_EXCEEDS_BALANCE", true);

        // lets check i we have lost one holdler
        if(totalTokenHolders > 0) { 
            if(_balances[sender] == 0) totalTokenHolders = totalTokenHolders.sub(1); 
        } //end if 
        

        // lets update holdlers info
        updateHoldlersInfo(sender, recipient);

    } //end 


    /**
     * @dev pre process transfer before the main transfer is done
     * @param sender the token sender
     * @param recipient the token recipient
     * @param amount the number of tokens to transfer
     */
     function _processBeforeTransfer(address sender, address recipient, uint256 amount,  bytes32 txType)  private returns(uint256) {


         // dont tax some operations
        if(txType    ==  TX_REMOVE_LIQUIDITY || isSwapAndLiquidifyLocked == true ) {
            return amount;
        }



        // if sender is excluded from fees
        if( excludedFromFees[sender] || // if sender is excluded from fee
            excludedFromFees[recipient] ||  // or recipient is excluded from fee
            excludedFromFees[msg.sender] // if the sender sending n behalf of the user is excluded from fee, dont take, this is used to whitelist dapp contracts
        ){
            return amount;
        }

        uint256 totalTxFee = getTotalFee();


        if(txType !=  TX_SELL  && sellTaxFee > 0) {
            totalTxFee = totalTxFee.sub(sellTaxFee);
        } 
        
        //lets get totalTax to deduct
        uint256 totalFeeAmount =  percentToAmount(totalTxFee, amount);


        //lets take the fee to system account
        internalTransfer(sender, _tokenAddress, totalFeeAmount, "TOTAL_FEE_AMOUNT_TRANSFER_ERROR", false);

        // take the fee amount from the amount
        uint256 amountMinusFee = amount.sub(totalFeeAmount);

        uint256 devFeeAmount;

        //lets check if dev fee is enabled 
        if(isDevFeeEnabled && devFee > 0){
            devFeeAmount = percentToAmount( devFee, amount);
        }

        uint256 marketingFeeAmount;

        if(isDevFeeEnabled && devFee > 0){
            devFeeAmount = percentToAmount( devFee, amount);
        }

        uint256 devAndMarketingAmt = devFeeAmount.add(marketingFeeAmount);

        if(devAndMarketingAmt > 0) {

            devAndMarketingFundPool = devAndMarketingFundPool.add(devAndMarketingAmt);

            if(txType == TX_TRANSFER) {

                uint256 devAndMarketingFundPoolSnapshot = devAndMarketingFundPool;

                __swapTokenForETH(devAndMarketingFundPoolSnapshot, devAndMarketingWallet);

                if(devAndMarketingFundPool > devAndMarketingFundPoolSnapshot){
                    devAndMarketingFundPool = devAndMarketingFundPool.sub(devAndMarketingFundPoolSnapshot);
                } else {
                    devAndMarketingFundPool = 0;
                }

            }

        } //end if 

        /////////////////////// START BUY BACK ////////////////////////

        // check and sell tokens for bnb
        if(isBuyBackEnabled && buyBackFee > 0){
            // handle buy back 
            handleBuyBack( sender, amount, txType );
        }//end if buyback is enabled


         //////////////////////////// START AUTO LIQUIDITY ////////////////////////
        if(isAutoLiquidityEnabled && autoLiquidityFee > 0){
            
           // lets set auto liquidity funds 
           autoLiquidityPool =  autoLiquidityPool.add( percentToAmount(autoLiquidityFee, amount) );

            
            //if tx is transfer only, lets do the sell or buy
            if(txType == TX_TRANSFER) {

                //take snapshot
                uint256 amountToLiquidify = autoLiquidityPool;

                if(amountToLiquidify >= minAmountBeforeAutoLiquidity){

                    //lets swap and provide liquidity
                    swapAndLiquidify(amountToLiquidify);

                    if(autoLiquidityPool > amountToLiquidify) {
                        //lets substract the amount token for liquidity from pool
                        autoLiquidityPool = autoLiquidityPool.sub(amountToLiquidify);
                    } else {
                        autoLiquidityPool = 0;
                    }

                } //end if amounToLiquidify >= minAmountBeforeAutoLiuqidity

            } //end if sender is not uniswap pair

        }//end if auto liquidity is enabled

        uint256 sellTaxAmountSplit;

        // so here lets check if its sell, lets get the sell tax amount
        // burn half and add half to 
        if( txType == TX_SELL  && isSellTaxEnabled && sellTaxFee > 0 ) {
            
            uint256 sellTaxAmount = percentToAmount(sellTaxFee, amount);

            sellTaxAmountSplit = sellTaxAmount.div(2);

            // lets add to be burned
            //autoBurnPool = autoBurnPool.add( sellTaxAmountSplit );

            // lets add to buyback pool
            buyBackTokenPool = buyBackTokenPool.add(sellTaxAmountSplit);

            pendingRewardTokenPool  = pendingRewardTokenPool.add(sellTaxAmountSplit);

        }

          //compute amount for liquidity providers fund
        if(isHoldlersRewardEnabled && holdlersRewardFee > 0) {
           
            pendingRewardTokenPool  = pendingRewardTokenPool.add( percentToAmount(holdlersRewardFee, amount) );

            if(txType == TX_TRANSFER && pendingRewardTokenPool > 0){

                uint256 __pendingRewardTokenPoolSnapShot = pendingRewardTokenPool;

                uint256 holdersRewardsAmountInRewardToken;

                if(rewardTokenAddress == address(this)  || rewardTokenAddress == address(0)){
                    holdersRewardsAmountInRewardToken = __pendingRewardTokenPoolSnapShot;
                } 
                else if(rewardTokenAddress == WETH){
                    //lets now convert to the particular tokens 
                    holdersRewardsAmountInRewardToken = __swapTokenForETH(__pendingRewardTokenPoolSnapShot, payable(address(this)));
                } else {
                    holdersRewardsAmountInRewardToken = __swapTokensForRewardTokens(__pendingRewardTokenPoolSnapShot);   
                }

                //reset pendingRewardTokenPool
                if(pendingRewardTokenPool > __pendingRewardTokenPoolSnapShot){
                    pendingRewardTokenPool = pendingRewardTokenPool.sub(__pendingRewardTokenPoolSnapShot);
                } else {
                    pendingRewardTokenPool = 0;
                }

                //if the holdlers rewards reserved pool is below what we want
                // assign all the rewards to the reserve pool, the reserved pool is used for
                // auto adjusting the rewards so that users wont get a decrease in rewards
                if( holdlersRewardReservedPool == 0 || 
                    (holdlersRewardMainPool > 0 && getPercentageDiffBetweenReservedAndMainHoldersRewardsPools() <= minPercentageOfholdlersRewardReservedPoolToMainPool)
                    ){
                    holdlersRewardReservedPool = holdlersRewardReservedPool.add(holdersRewardsAmountInRewardToken);

                } else {

                    // lets calculate the share of rewards for the the reserve pool
                    uint256 reservedPoolRewardShare = percentToAmount(percentageShareOfHoldlersRewardsForReservedPool, holdersRewardsAmountInRewardToken);

                    holdlersRewardReservedPool = holdlersRewardReservedPool.add(reservedPoolRewardShare);
                    
                    // set the main pool reward 
                    holdlersRewardMainPool  = holdlersRewardMainPool.add(holdersRewardsAmountInRewardToken.sub(reservedPoolRewardShare));

                } //end if 
                

                //totalRewardsTaken = totalRewardsTaken.add(holdlersRewardAmountInToken);
            } //end if its transfer 

        } //end if we have reward enabled


        return amountMinusFee;
    } //end preprocess 


    ////////////////  HandleBuyBack /////////////////
    function handleBuyBack(address sender, uint256 amount, bytes32 _txType) private {
        

        ////////////////////// DEDUCT THE BUYBACK FEE ///////////////

        uint256 buyBackTokenAmount = percentToAmount( buyBackFee, amount );

        buyBackTokenPool = buyBackTokenPool.add(buyBackTokenAmount);
        
        // if we have less ether, then sell token to buy more ethers
        if( buyBackETHPool <= minAmountBeforeSellingETHForBuyBack ){
            if( buyBackTokenPool >= minAmountBeforeSellingTokenForBuyBack && _txType == TX_TRANSFER ) {
                
                //console.log("in BuyBack Token Sell Zone ===>>>>>>>>>>>>>>>>> ");

                uint256 buyBackTokenSwapAmount = buyBackTokenPool;

                uint256 returnedETHValue = __swapTokenForETH(buyBackTokenSwapAmount, payable(address(this)));

                buyBackETHPool = buyBackETHPool.add(returnedETHValue);

                if(buyBackTokenPool >= buyBackTokenSwapAmount){
                    buyBackTokenPool = buyBackTokenPool.sub(buyBackTokenSwapAmount);
                } else {
                    buyBackTokenPool = 0; 
                }

            } ///end if 
        } //end i 
        
        // lets work on the buyback
        // here lets get the amount of bnb to be used for buy back sender != uniswapPair
        if( buyBackETHPool > minAmountBeforeSellingETHForBuyBack  && _txType == TX_TRANSFER ) {

            //console.log("BuyBackZone Entered ===>>>>>>>>>>>>>>>>> Hurrayyyyyyyyy");
            // use half of minAmountBeforeSellingETHForBuyBack to buy back
            uint256 amountToSellETH = minAmountBeforeSellingETHForBuyBack.div(2);
            
            // the buyBackETHAmountSplitDivisor
            uint256 amountToBuyBackAndBurn = amountToSellETH.div( buyBackETHAmountSplitDivisor );

            //console.log("amountToSellETH ===>>>>>>>>>>>>>>>>> ", amountToSellETH);
            //console.log("amountToBuyBack ===>>>>>>>>>>>>>>>>> ", amountToBuyBackAndBurn);
            
            if(buyBackETHPool > amountToSellETH) {
                buyBackETHPool = buyBackETHPool.sub(amountToSellETH);
            } else {
                amountToSellETH = 0;
            }

            //lets buy bnb and burn 
            uint256 totalTokensFromBuyBack = __swapETHForToken(amountToBuyBackAndBurn, this, burnAddress);

            totalBuyBacksAmountInTokens = totalBuyBacksAmountInTokens.add(totalTokensFromBuyBack);

            totalBuyBacksAmountInETH    = totalBuyBacksAmountInETH.add(amountToBuyBackAndBurn);
        }

    } //end handle 

    /**
    * @dev update holdlers account info, this info will be used for processing 
    * @param sender    the sendin account address
    * @param recipient the receiving account address
    */
    function updateHoldlersInfo(address sender, address recipient) private {

        //v2 we will use firstDepositTime, if the first time, lets set the initial deposit
        if(holdlersInfo[recipient].initialDepositTimestamp == 0){
            holdlersInfo[recipient].initialDepositTimestamp = block.timestamp;
        }

        // increment deposit count lol
        holdlersInfo[recipient].depositCount = holdlersInfo[recipient].depositCount.add(1);
        
        //if sender has no more tokens, lets remove his or data
        if(_balances[sender] == 0) {
            //user is no more holdling so we remove it
            delete holdlersInfo[sender];  
        }//end if 
        

    } //end process holdlEffect

    /**
     *  @dev release the acount rewards, this is called before transfer starts so that user will get the required amount to complete transfer
     *  @param _account the account to release the results to
     */
    function releaseAccountReward(address _account) private returns(bool) {

        //lets release sender's reward
        uint256 reward = getReward(_account);

        
        //dont bother processing if balance is 0
        if(reward < minimumRewardBeforeRelease || reward > holdlersRewardMainPool){
            return false;
        } 
        

        //lets deduct from our reward pool

        // now lets check if our reserve pool can cover that 
        if(holdlersRewardReservedPool >= reward) {
            
            // if the reward pool can cover that, deduct it from reserve 
            holdlersRewardReservedPool = holdlersRewardReservedPool.sub(reward);

        } else {
            
            // at this point, our reserve pool is down, so we deduct it from main pool
            holdlersRewardMainPool = holdlersRewardMainPool.sub(reward);

        }

        if(rewardTokenAddress == address(0) || rewardTokenAddress == address(this)) {
            // credit user the reward
            _balances[_account] = _balances[_account].add(reward);

            //lets get account info 
            holdlersInfo[_account].totalRewardReleased =  holdlersInfo[_account].totalRewardReleased.add(reward);
        } else {

            rewardTokenContract.transfer(_account, reward);
        }
            
        return true;
    } //end function


    /**
     * internally transfer amount between two accounts
     * @param _from the sender of the amount
     * @param _to  the recipient of the amount
     * @param emitEvent wether to emit an event on succss or not  
     */
    function internalTransfer(address _from, address _to, uint256 _amount, string memory errMsg, bool emitEvent) private {

        //set from balance
        _balances[_from] = _balances[_from].sub(_amount, string(abi.encodePacked("PBULL::INTERNAL_TRANSFER_SUB: ", errMsg)));

        //set _to Balance
        _balances[_to] = _balances[_to].add(_amount);

        if(emitEvent){
            emit Transfer(_from, _to, _amount); 
        }
    } //end internal transfer

    /**
     * @dev convert percentage value in Basis Point System to amount or token value
     * @param _percentInBps the percentage calue in basis point system
     * @param _amount the amount to be used for calculation
     * @return final value after calculation in uint256
     */
     function percentToAmount(uint256 _percentInBps, uint256 _amount) private pure returns(uint256) {
        //to get pbs,multiply percentage by 100
        return  (_amount.mul(_percentInBps)).div(10_000);
     }



    /**
     * @dev getPercentageOfReservedToMainRewardPool
     * @return uint256
     */
     function getPercentageDiffBetweenReservedAndMainHoldersRewardsPools() private view returns(uint256) {
        
        uint256 resultInPercent = ( holdlersRewardReservedPool.mul(100) ).div(holdlersRewardMainPool);

        // lets multiply by 100 to get the value in basis point system
        return (resultInPercent.mul(100));
     }


    //add initial lp
    bool _isAddInitialLiuqidityExecuted;

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

         //console.log("_amountToken=======>>>>", _amountToken);
          //console.log("allowance  =======>>>>", allowance(_msgSender(), address(this)) );

        //transferFrom(address(this), address(this), _amountToken);

        _approve(address(this), address(uniswapRouter), _amountToken );

        // add the liquidity
        uniswapRouter.addLiquidityETH { value: msg.value } (
            address(this), //token contract address
            _amountToken, // token amount we wish to provide liquidity for
            _amountToken, //amountTokenMin 
            msg.value, //amountETHMin
            _msgSender(), 
            block.timestamp.add(360) //deadline
        );

    } //end add liquidity

} //end contract