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

        address accessManagerAddress = address(0xDA4aAF85Bb924B53DCc2DFFa9e1A9C2Ef97aCFDF);
        AccessManager accessManager = AccessManager(accessManagerAddress);
        address oracleAggregator = 0xE3a31690392E8E18DC3d862651C079339E2c1ADE; // Mainnet Oracle Aggregator address
        accessManager.submitPendingOracle(
            IOracle(oracleAggregator),
            wstETHAddress,
            IOracle.Oracle({
                aggregator: AggregatorV3Interface(address(wstEthPriceFeed)),
                backupAggregator: AggregatorV3Interface(address(0)),
                heartbeat: 1 hours
            })
        );

        vm.stopBroadcast();
    }
}
