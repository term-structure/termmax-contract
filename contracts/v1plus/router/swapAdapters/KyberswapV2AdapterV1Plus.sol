// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "./ERC20SwapAdapterV1Plus.sol";

/**
 * @title KyberswapV1PlusAdapterV1Plus Scaling helper interface
 */
interface IKyberScalingHelper {
    /// @notice Get scaled input data for KyberswapV1Plus
    /// @param inputData The original swap data
    /// @param newAmount The new amount to scale the input data
    /// @return isSuccess Boolean indicating if the scaling was successful
    /// @return data The scaled input data
    function getScaledInputData(bytes calldata inputData, uint256 newAmount)
        external
        view
        returns (bool isSuccess, bytes memory data);
}

/**
 * @title TermMax KyberswapV2AdapterV1Plus
 * @author Term Structure Labs
 */
contract KyberswapV2AdapterV1Plus is ERC20SwapAdapterV1Plus {
    using Address for address;
    using TransferUtilsV1Plus for IERC20;

    error KyberScalingFailed(bytes errorData);

    address public immutable router;
    address public immutable KYBER_SCALING_HELPER;

    constructor(address router_, address scalingHelper_) {
        router = router_;
        KYBER_SCALING_HELPER = scalingHelper_;
    }

    function _swap(address, IERC20 tokenIn, IERC20, uint256 amountIn, bytes memory swapData)
        internal
        virtual
        override
        returns (uint256)
    {
        IERC20(tokenIn).safeIncreaseAllowance(address(router), amountIn);
        (bool isSuccess, bytes memory newSwapData) =
            IKyberScalingHelper(KYBER_SCALING_HELPER).getScaledInputData(swapData, amountIn);

        require(isSuccess, KyberScalingFailed(newSwapData));

        bytes memory returnData = router.functionCall(newSwapData);
        (uint256 tokenOutAmt,) = abi.decode(returnData, (uint256, uint256));
        return tokenOutAmt;
    }
}
