// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IRewardToken.sol";

contract Staking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IRewardToken public rewardToken;
    uint256 private rewardTokensPerBlock;
    uint256 private constant STAKER_SHARE_PRECISION = 1e12;

    struct PoolStaker {
        uint256 amount;
        uint256 rewards;
        uint256 lastRewardedBlock;
    }

    struct Pool {
        IERC20 stakeToken;
        uint256 tokensStaked;
        address[] stakers;
    }

    Pool[] public pools;
    mapping(uint256 => mapping(address => PoolStaker)) public poolStakers;

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount);
    event HarvestRewards(address indexed user, uint256 indexed poolId, uint256 amount);
    event PoolCreated(uint256 poolId);
    event RewardRateUpdated(uint256 newRewardTokensPerBlock);

    constructor(address _rewardTokenAddress, uint256 _rewardTokensPerBlock) {
        rewardToken = IRewardToken(_rewardTokenAddress);
        rewardTokensPerBlock = _rewardTokensPerBlock;
        (bool success, ) = _rewardTokenAddress.call(abi.encodeWithSignature("registerStakingContract()"));
        require(success, "unable to register token");
    }

    /**
     * @dev Create a new staking pool
     * @param _stakeToken The token to be staked in this pool
     */
    function createPool(IERC20 _stakeToken) external onlyOwner {
        Pool memory pool;
        pool.stakeToken =  _stakeToken;
        pools.push(pool);
        uint256 poolId = pools.length - 1;
        emit PoolCreated(poolId);
    }

    /**
     * @dev Add staker address to the pool stakers if it's not there already
     * We don't have to remove it because if it has amount 0 it won't affect rewards.
     * (but it might save gas in the long run)
     */
    function addStakerToPoolIfInexistent(uint256 _poolId, address depositingStaker) private {
        Pool storage pool = pools[_poolId];
        for (uint256 i; i < pool.stakers.length; i++) {
            address existingStaker = pool.stakers[i];
            if (existingStaker == depositingStaker) return;
        }
        pool.stakers.push(depositingStaker);
    }

    /**
     * @dev Deposit tokens to an existing pool
     * @param _poolId The ID of the pool to deposit tokens into
     * @param _amount The amount of tokens to deposit
     */
    function deposit(uint256 _poolId, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Deposit amount can't be zero");
        Pool storage pool = pools[_poolId];
        PoolStaker storage staker = poolStakers[_poolId][msg.sender];

        updateStakersRewards(_poolId);
        addStakerToPoolIfInexistent(_poolId, msg.sender);

        staker.amount += _amount;
        staker.lastRewardedBlock = block.number;
        pool.tokensStaked += _amount;

        emit Deposit(msg.sender, _poolId, _amount);
        pool.stakeToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @dev Withdraw all tokens from an existing pool
     * @param _poolId The ID of the pool to withdraw tokens from
     */
    function withdraw(uint256 _poolId) external nonReentrant {
        Pool storage pool = pools[_poolId];
        PoolStaker storage staker = poolStakers[_poolId][msg.sender];
        uint256 amount = staker.amount;
        require(amount > 0, "Withdraw amount can't be zero");

       // Harvest rewards before updating state
       _harvestRewards(_poolId, msg.sender);

       // Update state
       staker.amount = 0;
       pool.tokensStaked -= amount;

       emit Withdraw(msg.sender, _poolId, amount);

       // Perform the token transfer after state updates
       pool.stakeToken.safeTransfer(msg.sender, amount);
    }


    /**
     * @dev Harvest user rewards from a given pool id
     * @param _poolId The ID of the pool to harvest rewards from
     */
   function _harvestRewards(uint256 _poolId, address _staker) private {
        updateStakersRewards(_poolId);
        PoolStaker storage staker = poolStakers[_poolId][_staker];
        uint256 rewardsToHarvest = staker.rewards;
        staker.rewards = 0;
        emit HarvestRewards(_staker, _poolId, rewardsToHarvest);
        rewardToken.mint(_staker, rewardsToHarvest);
    }

    function harvestRewards(uint256 _poolId) public nonReentrant {
        _harvestRewards(_poolId, msg.sender);
    }

    /**
     * @dev Update the reward rate
     * @param _rewardTokensPerBlock The new reward tokens per block
     */
    function updateRewardRate(uint256 _rewardTokensPerBlock) external onlyOwner {
        rewardTokensPerBlock = _rewardTokensPerBlock;
        emit RewardRateUpdated(_rewardTokensPerBlock);
    }

    /**
     * @dev Getter for the rewardTokensPerBlock
     */
    function getRewardTokensPerBlock() external view returns (uint256) {
        return rewardTokensPerBlock;
    }

    
      /**
     * @dev Loops over all stakers from a pool, updating their accumulated rewards according
     * to their participation in the pool.
     */
    function updateStakersRewards(uint256 _poolId) private {
        Pool storage pool = pools[_poolId];
        for (uint256 i; i < pool.stakers.length; i++) {
            address stakerAddress = pool.stakers[i];
            PoolStaker storage staker = poolStakers[_poolId][stakerAddress];
            if (staker.amount == 0) continue;
            uint256 stakedAmount = staker.amount;
            uint256 stakerShare = (stakedAmount * STAKER_SHARE_PRECISION) / pool.tokensStaked;
            uint256 blocksSinceLastReward = block.number - staker.lastRewardedBlock;
            uint256 rewards = (blocksSinceLastReward * rewardTokensPerBlock * stakerShare) / STAKER_SHARE_PRECISION;
            staker.lastRewardedBlock = block.number;
            staker.rewards += rewards;
        }
    }
}
