// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract STToken is ERC20, Ownable {
    address public stakingContract;
    
    constructor(uint256 initialSupply) ERC20("Staking", "ST") {
        _mint(msg.sender, initialSupply);
    }

    function registerStakingContract() external {
        require(stakingContract == address(0), "one time setting");
        require(owner() == tx.origin, "EOA should be owner" );
        stakingContract = msg.sender;
    }   

    function mint(address to, uint amount) external {
        require(stakingContract == msg.sender, "Only staking contract can mint");
        _mint(to, amount);
    }

}