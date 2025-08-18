// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MarketViewerV1Plus} from "contracts/v1plus/router/MarketViewerV1Plus.sol";
import {StringHelper} from "../utils/StringHelper.sol";
import {DeployBase} from "./DeployBase.s.sol";

contract DeployMarketViewerV1Plus is DeployBase {
    // Network-specific config loaded from environment variables
    string network;
    uint256 deployerPrivateKey;
    address deployerAddr;

    function setUp() public {
        // Load network from environment variable
        network = vm.envString("NETWORK");
        string memory networkUpper = toUpper(network);

        // Load network-specific configuration
        string memory privateKeyVar = string.concat(networkUpper, "_DEPLOYER_PRIVATE_KEY");

        deployerPrivateKey = vm.envUint(privateKeyVar);
        deployerAddr = vm.addr(deployerPrivateKey);
    }

    function run() public {
        console.log("Network:", network);
        console.log("Deployer balance:", deployerAddr.balance);

        uint256 currentBlock = block.number;
        uint256 currentTimestamp = block.timestamp;

        vm.startBroadcast(deployerPrivateKey);
        // Deploy Market Viewer V1 Plus
        MarketViewerV1Plus marketViewer = new MarketViewerV1Plus();
        vm.stopBroadcast();

        console.log("===== Git Info =====");
        console.log("Git branch:", getGitBranch());
        console.log("Git commit hash:");
        console.logBytes(getGitCommitHash());
        console.log();

        console.log("===== Block Info =====");
        console.log("Block number:", currentBlock);
        console.log("Block timestamp:", currentTimestamp);
        console.log();

        console.log("===== Market Viewer V1 Plus Info =====");
        console.log("Deployer:", deployerAddr);
        console.log("Market Viewer V1 Plus deployed at:", address(marketViewer));
        console.log();

        // Write deployment results to a JSON file
        string memory deploymentJson = string(
            abi.encodePacked(
                "{\n",
                '  "network": "',
                network,
                '",\n',
                '  "deployedAt": "',
                vm.toString(block.timestamp),
                '",\n',
                '  "gitBranch": "',
                getGitBranch(),
                '",\n',
                '  "gitCommitHash": "0x',
                vm.toString(getGitCommitHash()),
                '",\n',
                '  "blockInfo": {\n',
                '    "number": "',
                vm.toString(currentBlock),
                '",\n',
                '    "timestamp": "',
                vm.toString(currentTimestamp),
                '"\n',
                "  },\n",
                '  "deployer": "',
                vm.toString(deployerAddr),
                '",\n',
                '  "contracts": {\n',
                '    "marketViewerV1Plus": "',
                vm.toString(address(marketViewer)),
                '"\n',
                "  }\n",
                "}"
            )
        );

        // Create deployment directory if it doesn't exist
        string memory deploymentsDir = string.concat(vm.projectRoot(), "/deployments/", network);
        if (!vm.exists(deploymentsDir)) {
            vm.createDir(deploymentsDir, true);
        }

        // Write the JSON file
        string memory filePath = string.concat(deploymentsDir, "/", network, "-market-viewer-v1-plus.json");
        vm.writeFile(filePath, deploymentJson);
        console.log("Deployment information written to:", filePath);
    }
}

// forge script script/deploy/DeployMarketViewerV1Plus.s.sol --rpc-url "https://arb-sepolia.g.alchemy.com/v2/1msadqC7wLHqAL0yEA_NxvASAkAaGRmY" --broadcast
