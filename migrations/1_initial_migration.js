const StakingContract = artifacts.require("StakingContract");
const stakingTokenAddress = "Your staking token address";

module.exports = function (deployer) {
  deployer.deploy(StakingContract, stakingTokenAddress);
};
