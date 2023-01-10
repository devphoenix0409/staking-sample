// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakingToken is ERC20 {
  constructor(uint256 _initialSupply) ERC20("Staking Token", "ST") {
    _mint(msg.sender, _initialSupply);
  }
}
