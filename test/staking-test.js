const { expect } = require("chai");
const helpers = require("@nomicfoundation/hardhat-network-helpers");

let staking, gold;

describe('Staking', function () {
    before(async () => {
        const accounts = await hre.ethers.getSigners();
        [admin, user1, user2] = accounts;

        // ERC20 token contract for reward and staking
        const GLDTokenFactory = await hre.ethers.getContractFactory("STToken");
        gold = await GLDTokenFactory.deploy(1000);
        await gold.deployed();

        // Staking contract
        const StakingFactory = await hre.ethers.getContractFactory("Staking");
        staking = await StakingFactory.deploy(gold.address, 1);    
        await staking.deployed();

        // Fund user1 and user2 accounts
        await gold.transfer(user1.address, 100);
        await gold.transfer(user2.address, 100);
    });

    it("Create pool", async () => {
        await expect(staking.createPool(gold.address))
            .to.emit(staking, 'PoolCreated')
            .withArgs(0);
    });

    it("Should stake successfully", async () => {
        const oStake = staking.connect(user1),
            oToken = gold.connect(user1),
            amount = 10,
            poolId = 0;

        await oToken.approve(staking.address, amount);

        await expect(oStake.deposit(poolId, amount))
            .to.emit(staking, 'Deposit')
            .withArgs(user1.address, poolId, amount);
    });

    it("Harvest tokens", async () => {
        const poolId = 0;
        const oStake = staking.connect(user1);

        // Mine 10 blocks to generate staking rewards
        await helpers.mine(10);

        await expect(oStake.harvestRewards(poolId))
            .to.emit(staking, 'HarvestRewards')
            .withArgs(user1.address, poolId, 11);
    });

    it("Should withdraw tokens successfully", async () => {
        const oStake = staking.connect(user1),
            poolId = 0,
            amount = 10;

         //mine 10 blocks to generate staking rewards
         await helpers.mine(10) ;

        await expect(oStake.withdraw(poolId))
            .to.emit(staking, 'Withdraw')
            .withArgs(user1.address, poolId, amount);
    });

    it("Should update reward rate", async () => {
        const newRate = 5;
        await expect(staking.updateRewardRate(newRate))
            .to.emit(staking, 'RewardRateUpdated')
            .withArgs(newRate);

        expect(await staking.getRewardTokensPerBlock()).to.equal(newRate);
    });

    it("Should fail to deposit zero tokens", async () => {
        const oStake = staking.connect(user1),
            amount = 0,
            poolId = 0;

        await expect(oStake.deposit(poolId, amount))
            .to.be.revertedWith("Deposit amount can't be zero");
    });

    it("Should fail to withdraw without staking", async () => {
        const oStake = staking.connect(user2),
            poolId = 0;

        await expect(oStake.withdraw(poolId))
            .to.be.revertedWith("Withdraw amount can't be zero");
    });

    it("Should fail to harvest without rewards", async () => {
        const oStake = staking.connect(user2),
            poolId = 0;

        await expect(oStake.harvestRewards(poolId))
            .to.emit(staking, 'HarvestRewards')
            .withArgs(user2.address, poolId, 0);
    });

});
