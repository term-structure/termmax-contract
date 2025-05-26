// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {TransferUtils, IERC20} from "contracts/lib/TransferUtils.sol";

abstract contract StakingBuffer {
    using TransferUtils for IERC20;

    error InvalidBuffer(uint256 minimumBuffer, uint256 maximumBuffer, uint256 buffer);

    struct BufferConfig {
        uint256 minimumBuffer;
        uint256 maximumBuffer;
        uint256 buffer;
    }

    function _depositWithBuffer(address assetAddr, uint256 amount) internal {
        uint256 assetBalance = IERC20(assetAddr).balanceOf(address(this));
        BufferConfig memory bufferConfig = _bufferConfig(assetAddr);
        if (assetBalance + amount > bufferConfig.maximumBuffer) {
        _depositToPool(assetAddr, assetBalance + amount - bufferConfig.buffer);
}
    }

    function _withdrawWithBuffer(address assetAddr, address to, uint256 amount) internal {
        uint256 assetBalance = IERC20(assetAddr).balanceOf(address(this));
        BufferConfig memory bufferConfig = _bufferConfig(assetAddr);
        
        if (assetBalance >= amount && assetBalance - amount >= bufferConfig.minimumBuffer) {
            // Sufficient buffer, transfer directly from contract balance
            IERC20(assetAddr).safeTransfer(to, amount);
        } else {
            // Need to withdraw from pool to maintain buffer and fulfill request
            uint256 targetBalance = bufferConfig.buffer + amount;
            if (targetBalance > assetBalance) {
                uint256 amountFromPool = targetBalance - assetBalance;
                _withdrawFromPool(assetAddr, address(this), amountFromPool);
            }
            
            // Transfer the full amount to user
            IERC20(assetAddr).safeTransfer(to, amount);
        }
    }

    function _bufferConfig(address assetAddr) internal view virtual returns (BufferConfig memory);

    function _depositToPool(address assetAddr, uint256 amount) internal virtual;

    function _withdrawFromPool(address assetAddr, address to, uint256 amount) internal virtual;

    function _checkBufferConfig(uint256 minimumBuffer, uint256 maximumBuffer, uint256 buffer) internal pure {
        if (minimumBuffer > maximumBuffer || buffer < minimumBuffer || buffer > maximumBuffer) {
            revert InvalidBuffer(minimumBuffer, maximumBuffer, buffer);
        }
    }
}
