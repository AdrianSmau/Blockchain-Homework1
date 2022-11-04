// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./openzeppelin/SafeMath.sol";
import "hardhat/console.sol";

// Base abstract class, that inherits from OpenZeppelin's Ownable in order to have access to ownership utilities
// Also, imports necessary classes from OpenZeppelin
abstract contract Funding is Ownable {

}
