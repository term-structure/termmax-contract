// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITermMaxMarket as ITermMaxMarketV1} from "../v1/ITermMaxMarket.sol";
import {ITermMaxMarketV1Plus} from "../v1plus/ITermMaxMarketV1Plus.sol";

/**
 * @title TermMax Market interface
 * @author Term Structure Labs
 */
interface ITermMaxMarket is ITermMaxMarketV1, ITermMaxMarketV1Plus {}
