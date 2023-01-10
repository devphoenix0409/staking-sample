// const StakingToken = artifacts.require("StakingToken");
const StakingContract = artifacts.require("StakingContract");
const stakingTokenAddress = "0x335446FF2B9bab408840d87AB6A21C9C0C6615C5";

module.exports = function (deployer) {
  // deployer.deploy(StakingToken, "10000000000000000000000000");
  deployer.deploy(StakingContract, stakingTokenAddress);
};
