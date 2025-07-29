// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeployBase} from "./DeployBase.s.sol";
import {ITermMaxVaultV1Plus} from "contracts/v1plus/vault/ITermMaxVaultV1Plus.sol";
import {ITermMaxVaultFactoryV1Plus} from "contracts/v1plus/factory/ITermMaxVaultFactoryV1Plus.sol";
import {AccessManager} from "contracts/v1/access/AccessManager.sol";
import {ITermMaxVault} from "contracts/v1/vault/ITermMaxVault.sol";

contract DeployVaultV1Plus is DeployBase {
    // Initialize vault configurations with a single USDC vault
    address assetAddr = address(0xE7e6EA2B6A1D7E7d80727290a86CCC9FE5fbe0C1);
    address curator = address(0x2A58A3D405c527491Daae4C62561B949e7F87EFE);
    address guardian = address(0x2A58A3D405c527491Daae4C62561B949e7F87EFE);
    address allocator = address(0x2A58A3D405c527491Daae4C62561B949e7F87EFE);
    string name = "TermMax USDC Vault V1 Plus";
    string symbol = "TMX-USDC-V1-PLUS";
    uint256 timelock = 1 seconds;
    uint256 maxCapacity = 50000000e6;
    uint64 performanceFeeRate = 1e7; // 10%
    uint64 minApy = 2e6; // 2%
    uint64 minIdleFundRate = 1e7; // 10%

    // Network-specific config loaded from environment variables
    string network;
    uint256 deployerPrivateKey;
    address accessManagerAddr;

    address vaultFactoryV1PlusAddr;

    struct VaultConfigV1Plus {
        address assetAddr;
        string name;
        string symbol;
        address curator;
        address guardian;
        address allocator;
        uint256 timelock;
        uint256 maxCapacity;
        uint64 performanceFeeRate;
        uint64 minApy;
        uint64 minIdleFundRate;
    }

    string coreContractPath;
    VaultConfigV1Plus vaultConfig;

    function setUp() public {
        vaultConfig = VaultConfigV1Plus({
            assetAddr: assetAddr,
            name: name,
            symbol: symbol,
            curator: curator,
            guardian: guardian,
            allocator: allocator,
            timelock: timelock,
            maxCapacity: maxCapacity,
            performanceFeeRate: performanceFeeRate,
            minApy: minApy,
            minIdleFundRate: minIdleFundRate
        });

        // Load network from environment variable
        network = vm.envString("NETWORK");
        string memory accessManagerPath =
            string.concat(vm.projectRoot(), "/deployments/", network, "/", network, "-access-manager.json");
        string memory json = vm.readFile(accessManagerPath);
        accessManagerAddr = vm.parseJsonAddress(json, ".contracts.accessManager");
        coreContractPath = string.concat(vm.projectRoot(), "/deployments/", network, "/", network, "-core.json");
        string memory networkUpper = toUpper(network);

        // Load network-specific configuration
        string memory privateKeyVar = string.concat(networkUpper, "_DEPLOYER_PRIVATE_KEY");

        deployerPrivateKey = vm.envUint(privateKeyVar);

        json = vm.readFile(coreContractPath);
        vaultFactoryV1PlusAddr = vm.parseJsonAddress(json, ".contracts.vaultFactoryV1Plus");
    }

    function run() public {
        uint256 currentBlockNum = block.number;
        uint256 currentTimestamp = block.timestamp;

        vm.startBroadcast(deployerPrivateKey);
        ITermMaxVaultV1Plus vault = deployVaultV1Plus(
            vaultFactoryV1PlusAddr,
            accessManagerAddr,
            vaultConfig.curator,
            vaultConfig.guardian,
            vaultConfig.timelock,
            vaultConfig.assetAddr,
            vaultConfig.maxCapacity,
            vaultConfig.name,
            vaultConfig.symbol,
            vaultConfig.performanceFeeRate,
            vaultConfig.minApy,
            vaultConfig.minIdleFundRate
        );

        AccessManager accessManager = AccessManager(accessManagerAddr);
        accessManager.setIsAllocatorForVault(ITermMaxVault(address(vault)), vaultConfig.allocator, true);

        writeDeploymentJson(currentBlockNum, currentTimestamp, vault, vaultConfig);

        vm.stopBroadcast();

        console.log("===== Git Info =====");
        console.log("Git branch:", getGitBranch());
        console.log("Git commit hash:");
        console.logBytes(getGitCommitHash());
        console.log();

        console.log("===== Vault V1Plus Info =====");
        console.log("Vault", vaultConfig.name, ":", address(vault));
        console.log("Deployed at block number:", currentBlockNum);
        console.log("");
    }

    function writeDeploymentJson(
        uint256 currentBlockNum,
        uint256 currentTimestamp,
        ITermMaxVaultV1Plus vault,
        VaultConfigV1Plus memory config
    ) public {
        // Write individual vault info to JSON
        string memory vaultPath = string.concat(
            vm.projectRoot(), "/deployments/", network, "/", network, "-vault-v1-plus-", vault.symbol(), ".json"
        );

        string memory vaultJson = generateVaultJson(currentBlockNum, currentTimestamp, vault, config);

        vm.writeFile(vaultPath, vaultJson);
        console.log("Vault info written to:", vaultPath);
    }

    function generateVaultJson(
        uint256 currentBlockNum,
        uint256 currentTimestamp,
        ITermMaxVaultV1Plus vault,
        VaultConfigV1Plus memory config
    ) internal returns (string memory) {
        string memory part1 = generateVaultJsonPart1(currentBlockNum, currentTimestamp);
        string memory part2 = generateVaultJsonPart2(vault, config);
        return string.concat(part1, part2);
    }

    function generateVaultJsonPart1(uint256 currentBlockNum, uint256 currentTimestamp)
        internal
        returns (string memory)
    {
        return string.concat(
            "{\n",
            '  "gitInfo": {\n',
            '    "branch": "',
            getGitBranch(),
            '",\n',
            '    "commit": "0x',
            vm.toString(getGitCommitHash()),
            '"\n',
            "  },\n",
            '  "blockInfo": {\n',
            '    "network": "',
            network,
            '",\n',
            '    "blockNumber": "',
            vm.toString(currentBlockNum),
            '",\n',
            '    "timestamp": "',
            vm.toString(currentTimestamp),
            '"\n',
            "  },\n"
        );
    }

    function generateVaultJsonPart2(ITermMaxVaultV1Plus vault, VaultConfigV1Plus memory config)
        internal
        view
        returns (string memory)
    {
        return string.concat(
            '  "vaultInfo": {\n',
            '    "name": "',
            config.name,
            '",\n',
            '    "symbol": "',
            config.symbol,
            '",\n',
            '    "address": "',
            vm.toString(address(vault)),
            '",\n',
            '    "asset": "',
            vm.toString(config.assetAddr),
            '",\n',
            '    "performanceFeeRate": ',
            vm.toString(config.performanceFeeRate),
            ",\n",
            '    "minApy": ',
            vm.toString(config.minApy),
            ",\n",
            '    "minIdleFundRate": ',
            vm.toString(config.minIdleFundRate),
            ",\n",
            '    "maxCapacity": "',
            vm.toString(config.maxCapacity),
            '",\n',
            '    "timelock": ',
            vm.toString(config.timelock),
            ",\n",
            '    "admin": "',
            vm.toString(accessManagerAddr),
            '",\n',
            '    "curator": "',
            vm.toString(config.curator),
            '",\n',
            '    "guardian": "',
            vm.toString(config.guardian),
            '",\n',
            '    "allocator": "',
            vm.toString(config.allocator),
            '"\n',
            "  }\n",
            "}"
        );
    }
}
