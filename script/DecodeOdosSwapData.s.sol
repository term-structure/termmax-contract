// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DecodeOdosSwapData
 * @notice Script to decode swapTokenInfo and related data from OdosV2Adapter and PendleSwapV3AdapterV2
 * @dev This script can decode the bytes data passed to various swap adapters
 */
contract DecodeOdosSwapData is Script {
    // Replicate the swapTokenInfo struct from IOdosRouterV2
    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    // Struct for Pendle swap data
    struct PendleSwapData {
        address ptMarketAddr;
        uint256 inAmount;
        uint256 minTokenOut;
    }

    /**
     * @notice Decode swap data bytes into readable components
     * @param swapData The encoded bytes data from OdosV2Adapter
     * @return tokenInfo The decoded swapTokenInfo struct
     * @return pathDefinition The path definition bytes
     * @return executor The executor address
     * @return referralCode The referral code
     */
    function decodeSwapData(bytes memory swapData)
        public
        pure
        returns (swapTokenInfo memory tokenInfo, bytes memory pathDefinition, address executor, uint32 referralCode)
    {
        (tokenInfo, pathDefinition, executor, referralCode) =
            abi.decode(swapData, (swapTokenInfo, bytes, address, uint32));
    }

    /**
     * @notice Display decoded swap data in console
     * @param swapData The encoded bytes data to decode and display
     */
    function displayDecodedOdosSwapData(bytes memory swapData) public view {
        (swapTokenInfo memory tokenInfo, bytes memory pathDefinition, address executor, uint32 referralCode) =
            decodeSwapData(swapData);

        console.log("=== Decoded OdosV2 Swap Data ===");
        console.log("");

        console.log("=== Token Info ===");
        console.log("Input Token:", tokenInfo.inputToken);
        console.log("Input Amount:", tokenInfo.inputAmount);
        console.log("Input Receiver:", tokenInfo.inputReceiver);
        console.log("Output Token:", tokenInfo.outputToken);
        console.log("Output Quote:", tokenInfo.outputQuote);
        console.log("Output Min:", tokenInfo.outputMin);
        console.log("Output Receiver:", tokenInfo.outputReceiver);
        console.log("");

        console.log("=== Additional Data ===");
        console.log("Executor:", executor);
        console.log("Referral Code:", referralCode);
        console.log("Path Definition Length:", pathDefinition.length);
        console.log("");
    }

    /**
     * @notice Decode Pendle swap data bytes into readable components
     * @param swapData The encoded bytes data from PendleSwapV3AdapterV2
     * @return pendleData The decoded Pendle swap data struct
     */
    function decodePendleSwapData(bytes memory swapData) public pure returns (PendleSwapData memory pendleData) {
        (pendleData.ptMarketAddr, pendleData.inAmount, pendleData.minTokenOut) =
            abi.decode(swapData, (address, uint256, uint256));
    }

    /**
     * @notice Display decoded Pendle swap data in console
     * @param swapData The encoded bytes data to decode and display
     */
    function displayDecodedPendleSwapData(bytes memory swapData) public view {
        PendleSwapData memory pendleData = decodePendleSwapData(swapData);

        console.log("=== Decoded Pendle Swap Data ===");
        console.log("");

        console.log("=== Pendle Swap Info ===");
        console.log("PT Market Address:", pendleData.ptMarketAddr);
        console.log("Input Amount:", pendleData.inAmount);
        console.log("Min Token Out:", pendleData.minTokenOut);
        console.log("");
    }

    /**
     * @notice Create sample Pendle swap data for testing
     * @dev This can be used to create test data for decoding
     */
    function createSamplePendleSwapData() public pure returns (bytes memory) {
        address samplePtMarketAddr = 0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2; // Example PT market
        uint256 sampleInAmount = 1000000000000000000; // 1 ETH in wei
        uint256 sampleMinTokenOut = 950000000000000000; // 0.95 ETH minimum (5% slippage)

        return abi.encode(samplePtMarketAddr, sampleInAmount, sampleMinTokenOut);
    }

    /**
     * @notice Encode sample swap data for testing
     * @dev This can be used to create test data for decoding
     */
    function createSampleSwapData() public pure returns (bytes memory) {
        swapTokenInfo memory sampleTokenInfo = swapTokenInfo({
            inputToken: 0xa0B86A33e6441e7f4DFCDe66BE8FE1e23A8D7C6f,
            inputAmount: 1000000000000000000, // 1 ETH in wei
            inputReceiver: 0x1234567890123456789012345678901234567890,
            outputToken: 0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
            outputQuote: 3000000000, // 3000 USDT (6 decimals)
            outputMin: 2950000000, // 2950 USDT minimum (1.67% slippage)
            outputReceiver: 0x1234567890123456789012345678901234567890
        });

        bytes memory samplePathDefinition = hex"0123456789abcdef";
        address sampleExecutor = 0x9876543210987654321098765432109876543210;
        uint32 sampleReferralCode = 12345;

        return abi.encode(sampleTokenInfo, samplePathDefinition, sampleExecutor, sampleReferralCode);
    }

    function run() public view {
        console.log("=== Multi-Adapter Swap Data Decoder ===");
        console.log("");

        // Decode Odos V2 Adapter sample data
        console.log("=== ODOS V2 ADAPTER EXAMPLE ===");
        bytes memory odosData =
            hex"000000000000000000000000ad55aebc9b8c03fc43cd9f62260391c13c23e7c000000000000000000000000000000000000000000000000a81c60fad7c3352d50000000000000000000000007882570840a97a490a37bd8db9e1ae39165bfbd6000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000bc7f66a000000000000000000000000000000000000000000000000000000000bc4f253000000000000000000000000c47591f5c023e44931c78d5a993834875b79fb1100000000000000000000000000000000000000000000000000000000000001400000000000000000000000007882570840a97a490a37bd8db9e1ae39165bfbd600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070010205006801010102030004ff00000000000000000000000000000000000000046dccb728c39f8aa69e47dac0ebdad8d2cddfe9ad55aebc9b8c03fc43cd9f62260391c13c23e7c0a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48d4fa2d31b7968e448877f69a96de69f5de8cd23e00000000000000000000000000000000";

        displayDecodedOdosSwapData(odosData);

        // Decode Pendle Adapter sample data
        console.log("=== PENDLE SWAP V3 ADAPTER EXAMPLE ===");
        // bytes memory pendleData = createSamplePendleSwapData();
        bytes memory pendleData =
            hex"0000000000000000000000003f53eb4c57c7e7118be8566bcd503ea502639581000000000000000000000000ad55aebc9b8c03fc43cd9f62260391c13c23e7c000000000000000000000000000000000000000000000000b0d7c13b54f5e86ae";
        displayDecodedPendleSwapData(pendleData);

        console.log("=== Usage Instructions ===");
        console.log("For OdosV2Adapter:");
        console.log("1. Call decodeSwapData(bytes) with your encoded data");
        console.log("2. Or call displayDecodedOdosSwapData(bytes) for formatted output");
        console.log("");
        console.log("For PendleSwapV3AdapterV2:");
        console.log("1. Call decodePendleSwapData(bytes) with your encoded data");
        console.log("2. Or call displayDecodedPendleSwapData(bytes) for formatted output");
        console.log("");
    }
}
