// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {IWstETH, WstETHPriceFeed, AggregatorV3Interface} from "contracts/v1/extensions/WstETHPriceFeed.sol";
import {AccessManager, IOracle} from "contracts/v1/access/AccessManager.sol";
import "forge-std/console.sol";

contract DeployWstEthPricefeed is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("ETH_MAINNET_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying WstEth Pricefeed...");
        address wstETHAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0; // Mainnet WstETH address
        address stETHPriceFeedAddress = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8; // Mainnet stETH price feed address
        console.log("WstETH Address:", wstETHAddress);
        console.log("stETH Price Feed Address:", stETHPriceFeedAddress);
        IWstETH wstETH = IWstETH(wstETHAddress); // Mainnet WstETH address
        AggregatorV3Interface stETHPriceFeed = AggregatorV3Interface(stETHPriceFeedAddress); // Mainnet stETH price feed address
        WstETHPriceFeed wstEthPriceFeed = new WstETHPriceFeed(wstETH, stETHPriceFeed);
        console.log("WstEth Pricefeed deployed at:", address(wstEthPriceFeed));
        (, int256 answer,,,) = wstEthPriceFeed.latestRoundData();
        console.log("latestAnswer:", answer);
        vm.stopBroadcast();
    }
}
