// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITermMaxRouter as ITermMaxRouterV1} from "../v1/router/ITermMaxRouter.sol";
import {ITermMaxRouterV1Plus} from "../v1plus/router/ITermMaxRouterV1Plus.sol";

/**
 * @title TermMax Router interface
 * @author Term Structure Labs
 */
interface ITermMaxRouter is ITermMaxRouterV1, ITermMaxRouterV1Plus {}
