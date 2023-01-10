// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingContract {
  address owner; // Owner of this contract

  IERC20 stakingToken; // Staking token address is same with reward token address

  struct Pool {
    uint256 poolId; // PoolId
    uint256 apr; // APR of Pool
    uint256 minimumStakeAmount; // Minimumstake Amount Pool
    uint256 maxSize; // MaxSize token capacity
    uint256 timeLock; // Timelock to WithDraw of Pool
    uint256 totalStakedAmount; // Total staked amount of Pool
    uint256 totalStakers; // Total staker count of Pool
  }

  struct UserInformation {
    uint256 poolId; // Poolid
    uint256 lastClaimedRewards; // Last Claimed Rewards of Pool
    uint256 timeDeposited; // getTimeDeposited of Pool
    uint256 stakingBalances; // Staking token balances of Pool
    uint256 rewardBalances; // Reward token balances of Pool
  }

  uint256 year = 31536000; // 365 days = 31536000s
  uint256 week = 604800; // 1 week = 604800s

  mapping(uint256 => Pool) public pools;

  mapping(address => UserInformation[]) public userInformations;

  // Check owner
  modifier onlyOwner() {
    require(msg.sender == owner, "Message sender must be the contract's owner.");
    _;
  }

  // Check poolId validate
  modifier validatePoolId(uint256 _poolId) {
    require(_poolId == 1 || _poolId == 2, "The pool with this poolId does not exist.");
    _;
  }

  // Check timelock
  modifier checkTimelock(uint256 _poolId) {
    require(
      block.timestamp >
        userInformations[msg.sender][_poolId].timeDeposited + pools[_poolId].timeLock,
      "Claims cannot be made during the time lock period."
    );
    _;
  }

  // ***************
  // EVENTS
  // ***************
  event CheckUserInformation(UserInformation userInformation);
  event UpdateUserInformation(bool success, UserInformation userInformation);
  event ClaimStakedToken(bool success, bool successRewards);
  event PoolInformation(Pool pool);

  constructor(address _stakingTokenAddress) {
    owner = msg.sender;
    stakingToken = IERC20(_stakingTokenAddress);

    pools[1] = Pool(
      1, // PoolId
      5, // APR of Pool1.
      100, // Minimumstake Amount Pool1 = 100 token.
      10000000, // Pool1 MaxSize token capacity: 10 Million.
      604800, // Timelock to WithDraw of Pool1 = 1 Week = 604800s.
      0, // Total staked amount of Pool
      0 // Total staker count of Pool
    );
    pools[2] = Pool(
      2, // PoolId
      4, // APR of Pool2.
      80, // Minimumstake Amount Pool2 = 80 token.
      20000000, // Pool2 MaxSize token capacity: 20 Million.
      259200, // Timelock to WithDraw of Pool2 = 1 Week = 259200s.
      0, // Total staked amount of Pool
      0 // Total staker count of Pool
    );
  }

  // Staking ERC20 token
  function stakeTokens(uint256 _amount, uint256 _poolId) external validatePoolId(_poolId) {
    // Check staking limit
    require(
      pools[_poolId].maxSize > pools[_poolId].totalStakedAmount + _amount,
      "Can't staking with this amount from the totalStakingAmount's limit."
    );

    bool success = stakingToken.transferFrom(msg.sender, address(this), _amount);

    if (success) {
      // Make sure this is a new staker.
      if (
        userInformations[msg.sender][_poolId].stakingBalances == 0 &&
        userInformations[msg.sender][_poolId].rewardBalances == 0
      ) {
        pools[_poolId].totalStakers++; // Calculate the total staker count of Pool
        userInformations[msg.sender][_poolId].poolId = _poolId; // Set the poolId
        userInformations[msg.sender][_poolId].lastClaimedRewards = block.timestamp; // Set the init lastClaimedRewards
      }

      pools[_poolId].totalStakedAmount += _amount; // Calculate the total stake amount
      userInformations[msg.sender][_poolId].stakingBalances += _amount; // Add staking amount of sender
      userInformations[msg.sender][_poolId].timeDeposited = block.timestamp; // Update the time deposited of sender
    }

    emit UpdateUserInformation(success, userInformations[msg.sender][_poolId]);
  }

  // Claim Rewards
  function claimRewards(uint256 _amount, uint256 _poolId)
    external
    validatePoolId(_poolId)
    checkTimelock(_poolId)
  {
    uint256 rewards = this.rewardsCalculator(_poolId); // Calculate the added rewards
    require(rewards > _amount, "Rewards is not enough to claim this amount."); // Check if you can claim rewards

    bool success = stakingToken.transfer(msg.sender, _amount);

    if (success) {
      userInformations[msg.sender][_poolId].rewardBalances -= _amount; // Update rewardBalances
      userInformations[msg.sender][_poolId].lastClaimedRewards = block.timestamp; // Update lastClaimedRewards
    }

    emit UpdateUserInformation(success, userInformations[msg.sender][_poolId]);
  }

  // reStaking function is compound to restake his token if user not wants to claim token.
  function stakeRewards(uint256 _poolId) external validatePoolId(_poolId) {
    uint256 rewards = this.rewardsCalculator(_poolId); // Calculate the added rewards

    // Update stakingBalances
    userInformations[msg.sender][_poolId].rewardBalances += rewards;
    userInformations[msg.sender][_poolId].stakingBalances += userInformations[msg.sender][_poolId]
      .rewardBalances;

    userInformations[msg.sender][_poolId].rewardBalances = 0; // Set rewardBalances to zero
    userInformations[msg.sender][_poolId].lastClaimedRewards = block.timestamp; // Update lastClaimedRewards

    emit CheckUserInformation(userInformations[msg.sender][_poolId]);
  }

  // This function should be if a user staked he unstake the token then it should not get the amount asap there should be the time.stamp + 1 Week and then claim tokensFromStake.
  function unlockToWithdraw(uint256 _poolId) private validatePoolId(_poolId) {
    userInformations[msg.sender][_poolId].timeDeposited = block.timestamp + week;
  }

  // Claim's also the Unclaimed if there is Unclaimed.(if else)
  function claimStakedToken(uint256 _poolId)
    external
    validatePoolId(_poolId)
    checkTimelock(_poolId)
  {
    // Call the unlockToWithdraw function
    unlockToWithdraw(_poolId);

    bool successStakes = stakingToken.transfer(
      msg.sender,
      userInformations[msg.sender][_poolId].stakingBalances
    );

    if (successStakes) {
      pools[_poolId].totalStakedAmount -= userInformations[msg.sender][_poolId].stakingBalances; // Update the totalStakedAmount
      userInformations[msg.sender][_poolId].stakingBalances = 0; // Set the staking balance to zero
    }

    uint256 rewards = this.rewardsCalculator(_poolId); // Calculate the added rewards
    bool successRewards = stakingToken.transfer(msg.sender, rewards);

    if (successRewards) {
      userInformations[msg.sender][_poolId].rewardBalances = 0; // Set the reward balance to zero
      userInformations[msg.sender][_poolId].lastClaimedRewards = block.timestamp; // Update lastClaimedRewards
    }

    if (successRewards && successStakes) {
      pools[_poolId].totalStakers--; // Calculate the total staker count of Pool
    }

    emit ClaimStakedToken(successStakes, successRewards);
  }

  // Get Current Reward By Staker index
  function rewardsCalculator(uint256 _poolId)
    external
    view
    validatePoolId(_poolId)
    returns (uint256)
  {
    uint256 rewardTime = block.timestamp - userInformations[msg.sender][_poolId].lastClaimedRewards;
    uint256 stakingBalances = userInformations[msg.sender][_poolId].stakingBalances;
    uint256 rewards = (rewardTime * stakingBalances * pools[_poolId].apr) / (100 * year);
    uint256 currentRewards = userInformations[msg.sender][_poolId].rewardBalances + rewards;

    return currentRewards;
  }

  // This should be the amount of calculated reward a user don't have claimed.
  function unclaimedAmount(uint256 _poolId)
    external
    view
    validatePoolId(_poolId)
    returns (uint256)
  {
    return userInformations[msg.sender][_poolId].stakingBalances;
  }

  // Set the APR
  function setAPR(uint256 _apr, uint256 _poolId) external onlyOwner validatePoolId(_poolId) {
    pools[_poolId].apr = _apr;

    emit PoolInformation(pools[_poolId]);
  }

  // Set the minimumStakeAmount
  function setMinimumStakeAmount(uint256 _minimumStakeAmount, uint256 _poolId)
    external
    onlyOwner
    validatePoolId(_poolId)
  {
    pools[_poolId].minimumStakeAmount = _minimumStakeAmount;

    emit PoolInformation(pools[_poolId]);
  }

  // Set the maxSize
  function setMaxSize(uint256 _maxSize, uint256 _poolId)
    external
    onlyOwner
    validatePoolId(_poolId)
  {
    pools[_poolId].maxSize = _maxSize;

    emit PoolInformation(pools[_poolId]);
  }

  // Set the timeLock
  function setTimeLock(uint256 _timeLock, uint256 _poolId)
    external
    onlyOwner
    validatePoolId(_poolId)
  {
    pools[_poolId].timeLock = _timeLock;

    emit PoolInformation(pools[_poolId]);
  }
}
