// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "./ERC20SwapAdapterV1Plus.sol";

/**
 * @title TermMax ERC4626VaultAdapterV1Plus
 * @author Term Structure Labs
 */
contract ERC4626VaultAdapterV1Plus is ERC20SwapAdapterV1Plus {
    using TransferUtilsV1Plus for IERC20;
    using Math for uint256;

    enum Action {
        Deposit,
        Redeem
    }

    error InvalidAction();

    function _swap(address recipient, IERC20 tokenIn, IERC20 tokenOut, uint256 amount, bytes memory swapData)
        internal
        virtual
        override
        returns (uint256 tokenOutAmt)
    {
        (Action action, uint256 inAmount, uint256 minTokenOut) = abi.decode(swapData, (Action, uint256, uint256));
        /**
         * Note: Scaling Input/Output amount (round up)
         */
        minTokenOut = minTokenOut.mulDiv(amount, inAmount, Math.Rounding.Ceil);

        if (action == Action.Deposit) {
            tokenIn.safeIncreaseAllowance(address(tokenOut), amount);
            tokenOutAmt = IERC4626(address(tokenOut)).deposit(amount, recipient);
            if (tokenOutAmt < minTokenOut) {
                revert LessThanMinTokenOut(tokenOutAmt, minTokenOut);
            }
        } else if (action == Action.Redeem) {
            tokenOutAmt = IERC4626(address(tokenIn)).redeem(amount, recipient, address(this));
            if (tokenOutAmt < minTokenOut) {
                revert LessThanMinTokenOut(tokenOutAmt, minTokenOut);
            }
        } else {
            revert InvalidAction();
        }
    }
}
