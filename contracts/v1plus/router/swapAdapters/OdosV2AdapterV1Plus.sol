// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20SwapAdapterV1Plus.sol";

/**
 * @title OdosRouterV1Plus interface
 */
interface IOdosRouterV1Plus {
    /// @notice Struct to hold swap token information
    struct SwapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    function swap(SwapTokenInfo memory tokenInfo, bytes calldata pathDefinition, address executor, uint32 referralCode)
        external
        payable
        returns (uint256 amountOut);
}

/**
 * @title TermMax OdosV2AdapterV1Plus
 * @author Term Structure Labs
 */
contract OdosV2AdapterV1Plus is ERC20SwapAdapterV1Plus {
    using TransferUtilsV1Plus for IERC20;
    using Math for uint256;

    IOdosRouterV1Plus public immutable router;

    constructor(address router_) {
        router = IOdosRouterV1Plus(router_);
    }

    function _swap(address recipient, IERC20 tokenIn, IERC20, uint256 amountIn, bytes memory swapData)
        internal
        virtual
        override
        returns (uint256 tokenOutAmt)
    {
        tokenIn.safeIncreaseAllowance(address(router), amountIn);

        (
            IOdosRouterV1Plus.SwapTokenInfo memory tokenInfo,
            bytes memory pathDefinition,
            address executor,
            uint32 referralCode
        ) = abi.decode(swapData, (IOdosRouterV1Plus.SwapTokenInfo, bytes, address, uint32));

        /**
         * Note: Scaling Input/Output amount
         */
        tokenInfo.outputQuote = tokenInfo.outputQuote.mulDiv(amountIn, tokenInfo.inputAmount, Math.Rounding.Ceil);
        tokenInfo.outputMin = tokenInfo.outputMin.mulDiv(amountIn, tokenInfo.inputAmount, Math.Rounding.Ceil);
        tokenInfo.inputAmount = amountIn;
        tokenInfo.outputReceiver = recipient;

        tokenOutAmt = router.swap(tokenInfo, pathDefinition, executor, referralCode);
    }
}
