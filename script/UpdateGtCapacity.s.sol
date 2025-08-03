// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DeployBase} from "./deploy/DeployBase.s.sol";

// Interface for the Access Manager
interface IAccessManager {
    function updateGtConfig(address market, bytes memory configData) external;
    function CONFIGURATOR_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

// Interface for TermMax Market
interface ITermMaxMarket {
    function tokens() external view returns (IERC20, IERC20, address, address, IERC20);
}

// Interface for Gearing Token
interface IGearingToken {
    function collateralCapacity() external view returns (uint256);
}

/**
 * @title UpdateSingleGTCapacity
 * @notice Forge script to update a single GT collateral capacity through the access manager
 * @dev Market address and capacity are configured in the script, network config loaded from environment
 */
contract UpdateGtCapacity is DeployBase {
    // CONFIGURATION - Update these values before running the script
    // ===============================================================

    // The address of the Market contract to update
    address public constant MARKET_ADDRESS = 0x46F6a23B697FFFd8f5D66B1DE99A2933bB6e001D; // Replace with actual market address

    // The new collateral capacity value (in wei) to set for the GT
    uint256 public constant NEW_GT_CAPACITY = 20000000e18; // Example: 1,000 tokens with 18 decimals

    // ===============================================================

    // Network-specific config loaded from environment variables
    string network;
    uint256 deployerPrivateKey;
    address deployerAddr;

    // Loaded from deployment files
    address accessManagerAddr;

    function setUp() public {
        // Load network from environment variable
        network = vm.envString("NETWORK");
        string memory networkUpper = toUpper(network);

        // Load network-specific configuration
        string memory privateKeyVar = string.concat(networkUpper, "_DEPLOYER_PRIVATE_KEY");

        deployerPrivateKey = vm.envUint(privateKeyVar);
        deployerAddr = vm.addr(deployerPrivateKey);
    }

    function loadAddressConfig() internal {
        string memory accessManagerPath =
            string.concat(vm.projectRoot(), "/deployments/", network, "/", network, "-access-manager.json");
        string memory json = vm.readFile(accessManagerPath);
        accessManagerAddr = vm.parseJsonAddress(json, ".contracts.accessManager");
    }

    function run() public {
        // Load access manager address from deployment files
        loadAddressConfig();

        // Validate configuration
        require(accessManagerAddr != address(0), "Access Manager address not loaded");
        require(MARKET_ADDRESS != address(0), "Market address not set");
        require(NEW_GT_CAPACITY > 0, "New capacity must be greater than 0");

        uint256 currentBlockNum = block.number;
        uint256 currentTimestamp = block.timestamp;

        // Print script configuration
        printConfiguration();

        // Check if deployer has configurator role
        IAccessManager accessManager = IAccessManager(accessManagerAddr);
        bytes32 configuratorRole = accessManager.CONFIGURATOR_ROLE();
        bool hasRole = accessManager.hasRole(configuratorRole, deployerAddr);

        if (!hasRole) {
            console2.log("ERROR: Deployer does not have CONFIGURATOR_ROLE. Cannot update GT config.");
            return;
        }

        // Get GT contract address from market
        ITermMaxMarket market = ITermMaxMarket(MARKET_ADDRESS);
        address gtAddress;
        try market.tokens() returns (IERC20, IERC20, address gtAddr, address collateralAddr, IERC20 underlying) {
            gtAddress = gtAddr;
            console2.log(string.concat("GT Name: ", IERC20Metadata(gtAddress).name()));
            console2.log(string.concat("GT Address: ", vm.toString(gtAddress)));
            console2.log(string.concat("Collateral Address: ", vm.toString(collateralAddr)));
            console2.log(string.concat("Underlying Address: ", vm.toString(address(underlying))));
        } catch {
            console2.log("ERROR: Failed to get token addresses from market.");
            return;
        }

        // Get current collateral capacity for comparison
        IGearingToken gt = IGearingToken(gtAddress);
        uint256 currentCapacity;
        try gt.collateralCapacity() returns (uint256 capacity) {
            currentCapacity = capacity;
            console2.log(string.concat("Current GT capacity: ", vm.toString(currentCapacity)));
        } catch {
            console2.log("WARNING: Could not retrieve current capacity (continuing anyway)");
        }

        // Encode new capacity as config data
        bytes memory configData = abi.encode(NEW_GT_CAPACITY);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Update GT config through access manager
        try accessManager.updateGtConfig(MARKET_ADDRESS, configData) {
            console2.log("Successfully sent updateGtConfig transaction.");
        } catch Error(string memory reason) {
            console2.log(string.concat("Failed to update GT config: ", reason));
            vm.stopBroadcast();
            return;
        } catch {
            console2.log("Failed to update GT config: Unknown error");
            vm.stopBroadcast();
            return;
        }

        vm.stopBroadcast();

        console2.log("===== Git Info =====");
        console2.log("Git branch:", getGitBranch());
        console2.log("Git commit hash:");
        console2.logBytes(getGitCommitHash());
        console2.log();

        console2.log("===== Block Info =====");
        console2.log("Block number:", currentBlockNum);
        console2.log("Block timestamp:", currentTimestamp);
        console2.log();

        // Verify the update (this will only work with local simulations or --slow flag)
        try gt.collateralCapacity() returns (uint256 updatedCapacity) {
            console2.log(string.concat("Updated GT capacity: ", vm.toString(updatedCapacity)));
            if (updatedCapacity == NEW_GT_CAPACITY) {
                console2.log("[SUCCESS] GT collateral capacity successfully updated!");
            } else {
                console2.log(
                    "[WARNING] Note: Updated capacity doesn't match specified capacity. This may be normal if verifying against a fork."
                );
            }
        } catch {
            console2.log(
                "Note: Could not verify the updated capacity. This is normal when broadcasting to live networks."
            );
        }
    }

    function printConfiguration() internal view {
        console2.log("=== Update Single GT Capacity Configuration ===");
        console2.log("Network:", network);
        console2.log(string.concat("Access Manager: ", vm.toString(accessManagerAddr)));
        console2.log(string.concat("Market Address: ", vm.toString(MARKET_ADDRESS)));
        console2.log(string.concat("New GT Capacity: ", vm.toString(NEW_GT_CAPACITY)));
        console2.log(string.concat("Deployer: ", vm.toString(deployerAddr)));
        console2.log("==============================================");
    }
}
