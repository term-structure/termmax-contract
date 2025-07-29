// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/console.sol";
import {DeployBase} from "./DeployBase.s.sol";
import {ITermMaxVaultFactoryV1Plus} from "contracts/v1plus/factory/ITermMaxVaultFactoryV1Plus.sol";

contract DeployVaultFactoryV1Plus is DeployBase {
    // Network-specific config loaded from environment variables
    string network;
    uint256 deployerPrivateKey;
    address deployerAddr;

    ITermMaxVaultFactoryV1Plus vaultFactoryV1Plus;

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
        // deploy vault factory v1 plus
        vaultFactoryV1Plus = deployVaultFactoryV1Plus();
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

        console.log("===== Vault Factory V1Plus Info =====");
        console.log("Deployer:", deployerAddr);
        console.log("Vault Factory V1Plus deployed at:", address(vaultFactoryV1Plus));
        console.log("Vault Implementation:", vaultFactoryV1Plus.TERMMAX_VAULT_IMPLEMENTATION());
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
                '    "vaultFactoryV1Plus": "',
                vm.toString(address(vaultFactoryV1Plus)),
                '",\n',
                '    "vaultImplementationV1Plus": "',
                vm.toString(vaultFactoryV1Plus.TERMMAX_VAULT_IMPLEMENTATION()),
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
        string memory filePath = string.concat(deploymentsDir, "/", network, "-vault-factory-v1-plus.json");
        vm.writeFile(filePath, deploymentJson);
        console.log("Deployment information written to:", filePath);
    }
}
