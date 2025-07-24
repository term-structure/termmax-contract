// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20SwapAdapterV1Plus, IERC20} from "./ERC20SwapAdapterV1Plus.sol";
import {ITermMaxOrder} from "contracts/interfaces/ITermMaxOrder.sol";
import {TransferUtilsV1Plus} from "../../lib/TransferUtilsV1Plus.sol";

struct TermMaxSwapData {
    bool swapExactTokenForToken;
    address tokenIn;
    address tokenOut;
    address[] orders;
    uint128[] tradingAmts;
    uint128 netTokenAmt;
    uint256 deadline;
}

contract TermMaxSwapAdapter is ERC20SwapAdapterV1Plus {
    using TransferUtilsV1Plus for IERC20;

    error OrdersAndAmtsLengthNotMatch();

    function _swap(address recipient, IERC20 tokenIn, IERC20 tokenOut, uint256 tokenInAmt, bytes memory swapData)
        internal
        virtual
        override
        returns (uint256 netTokenOutOrIn)
    {
        TermMaxSwapData memory data = abi.decode(swapData, (TermMaxSwapData));
        if (data.orders.length != data.tradingAmts.length) revert OrdersAndAmtsLengthNotMatch();

        if (data.swapExactTokenForToken) {
            for (uint256 i = 0; i < data.orders.length; ++i) {
                address order = data.orders[i];
                tokenIn.forceApprove(order, data.tradingAmts[i]);
                netTokenOutOrIn += ITermMaxOrder(order).swapExactTokenToToken(
                    tokenIn, tokenOut, recipient, data.tradingAmts[i], 0, data.deadline
                );
            }
            if (netTokenOutOrIn < data.netTokenAmt) revert LessThanMinTokenOut(netTokenOutOrIn, data.netTokenAmt);
        } else {
            for (uint256 i = 0; i < data.orders.length; ++i) {
                address order = data.orders[i];
                // Use maximum allowance for the swap because the final input amount is unknown
                tokenIn.forceApprove(order, data.netTokenAmt);
                netTokenOutOrIn += ITermMaxOrder(order).swapTokenToExactToken(
                    tokenIn, tokenOut, recipient, data.tradingAmts[i], data.netTokenAmt, data.deadline
                );
            }
            if (netTokenOutOrIn > data.netTokenAmt) revert LessThanMinTokenOut(netTokenOutOrIn, data.netTokenAmt);
        }
    }
}
