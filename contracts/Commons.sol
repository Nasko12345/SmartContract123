// SPDX-License-Identifier: MIT

/**
 * PowerBull (https://powerbull.net)
 * @author PowerBull <hello@powerbull.net>
 */
 
pragma solidity ^0.8.4;
pragma abicoder v2;
import "./libs/_IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Commons is Ownable {
    
    /**
     * move tokens on emergency cases
     */
    function emergencyWithdrawTokens(address _contractAddress, address _toAddress, uint256 _amount) public onlyOwner {
        
        _IERC20 erc20Token  =  _IERC20(_contractAddress);

        uint256 balance = erc20Token.balanceOf(address(this));
        
        if(balance >= _amount){
            erc20Token.transfer(_toAddress, _amount);
        }
    } //end function


    /**
     * move Ethers on emergency cases
     */
    function emergencyWithdrawEthers(address payable _toAddress,  uint256 _amount) public onlyOwner {
        
        uint256 balance = address(this).balance;

        if(balance >= _amount){
            _toAddress.transfer(_amount);
        }
    }

}