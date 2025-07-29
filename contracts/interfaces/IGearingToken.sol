// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGearingToken as IGearingTokenV1} from "../v1/tokens/IGearingToken.sol";
import {IGearingTokenV1Plus} from "../v1plus/tokens/IGearingTokenV1Plus.sol";

/**
 * @title Gearing Token interface
 * @author Term Structure Labs
 */
interface IGearingToken is IGearingTokenV1, IGearingTokenV1Plus {}
