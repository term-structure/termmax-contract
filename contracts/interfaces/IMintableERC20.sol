// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMintableERC20 as IMintableERC20V1} from "../v1/tokens/IMintableERC20.sol";
import {IMintableERC20V1Plus} from "../v1plus/tokens/IMintableERC20V1Plus.sol";

/**
 * @title Mintable ERC20 interface
 * @author Term Structure Labs
 */
interface IMintableERC20 is IMintableERC20V1, IMintableERC20V1Plus {}
