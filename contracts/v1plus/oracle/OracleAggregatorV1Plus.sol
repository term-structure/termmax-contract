// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title OracleAggregatorV1Plus
 * @author Term Structure Labs
 * @notice Enhanced oracle aggregator for TermMax V1Plus protocol with improved price feed management
 * @dev This contract references design concepts from AAVE's oracle system
 * Implements price feed aggregation with primary and backup oracles,
 * staleness checks via heartbeats, and governance-controlled updates with timelocks
 * similar to AAVE's oracle architecture
 *
 * Key V1Plus improvements over V1:
 * - Independent heartbeat configuration for backup oracles
 * - Price capping mechanism with maxPrice parameter
 * - Oracle revocation capability for enhanced security
 */
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {AggregatorV3Interface, IOracleV1Plus} from "./IOracleV1Plus.sol";

contract OracleAggregatorV1Plus is IOracleV1Plus, Ownable2Step {
    /// @notice The timelock period in seconds that must elapse before pending oracles can be accepted
    /// @dev Immutable value set during contract construction for security
    uint256 internal immutable _timeLock;

    /**
     * @notice Structure for storing pending oracle updates with timelock protection
     * @param oracle The oracle configuration waiting to be activated
     * @param validAt The timestamp when this pending oracle can be accepted
     */
    struct PendingOracle {
        Oracle oracle;
        uint64 validAt;
    }

    /// @notice Error thrown when the asset or oracle address is invalid
    error InvalidAssetOrOracle();

    /**
     * @notice Error thrown when trying to accept a change that has no pending value
     */
    error NoPendingValue();

    /**
     * @notice Error thrown when trying to accept a change before the timelock period has elapsed
     */
    error TimelockNotElapsed();

    /**
     * @notice Event emitted when an oracle configuration is updated
     * @param asset The address of the asset whose oracle was updated
     * @param aggregator The address of the primary aggregator
     * @param backupAggregator The address of the backup aggregator
     * @param maxPrice The maximum price cap for this asset (0 = no cap)
     * @param minPrice The minimum price floor for this asset (0 = no floor)
     * @param heartbeat The staleness threshold for the primary aggregator
     * @param backupHeartbeat The staleness threshold for the backup aggregator
     */
    event UpdateOracle(
        address indexed asset,
        AggregatorV3Interface indexed aggregator,
        AggregatorV3Interface indexed backupAggregator,
        int256 maxPrice,
        int256 minPrice,
        uint32 heartbeat,
        uint32 backupHeartbeat
    );

    /**
     * @notice Event emitted when a pending oracle is submitted
     * @param asset The address of the asset for the pending oracle
     * @param aggregator The address of the primary aggregator
     * @param backupAggregator The address of the backup aggregator
     * @param maxPrice The maximum price cap for this asset
     * @param minPrice The minimum price floor for this asset (0 = no floor)
     * @param heartbeat The staleness threshold for the primary aggregator
     * @param backupHeartbeat The staleness threshold for the backup aggregator
     * @param validAt The timestamp when this pending oracle can be accepted
     */
    event SubmitPendingOracle(
        address indexed asset,
        AggregatorV3Interface indexed aggregator,
        AggregatorV3Interface indexed backupAggregator,
        int256 maxPrice,
        int256 minPrice,
        uint32 heartbeat,
        uint32 backupHeartbeat,
        uint64 validAt
    );

    /**
     * @notice Event emitted when a pending oracle is revoked
     * @param asset The address of the asset whose pending oracle was revoked
     */
    event RevokePendingOracle(address indexed asset);

    /// @notice Mapping of asset addresses to their active oracle configurations
    /// @dev Contains the currently live oracle settings for each asset
    mapping(address => Oracle) public oracles;

    /// @notice Mapping of asset addresses to their pending oracle configurations
    /// @dev Contains oracle updates waiting for timelock expiration
    mapping(address => PendingOracle) public pendingOracles;

    constructor(address _owner, uint256 timeLock) Ownable(_owner) {
        _timeLock = timeLock;
    }

    /**
     * @inheritdoc IOracleV1Plus
     */
    function submitPendingOracle(address asset, Oracle memory oracle) external onlyOwner {
        // Handle oracle removal case
        if (address(oracle.aggregator) == address(0) && address(oracle.backupAggregator) == address(0)) {
            delete oracles[asset];
            emit UpdateOracle(asset, AggregatorV3Interface(address(0)), AggregatorV3Interface(address(0)), 0, 0, 0, 0);
            return;
        }

        // Validate inputs for oracle addition/update
        if (asset == address(0) || oracle.aggregator == AggregatorV3Interface(address(0))) {
            revert InvalidAssetOrOracle();
        }

        // Ensure backup aggregator has same decimals as primary if both are present
        if (address(oracle.backupAggregator) != address(0)) {
            if (oracle.aggregator.decimals() != oracle.backupAggregator.decimals()) {
                revert InvalidAssetOrOracle();
            }
        }

        // Store pending oracle with timelock
        uint64 validAt = uint64(block.timestamp + _timeLock);
        pendingOracles[asset] = PendingOracle({oracle: oracle, validAt: validAt});

        emit SubmitPendingOracle(
            asset,
            oracle.aggregator,
            oracle.backupAggregator,
            oracle.maxPrice,
            oracle.minPrice,
            oracle.heartbeat,
            oracle.backupHeartbeat,
            validAt
        );
    }

    /**
     * @inheritdoc IOracleV1Plus
     */
    function acceptPendingOracle(address asset) external {
        if (pendingOracles[asset].validAt == 0) {
            revert NoPendingValue();
        }
        if (block.timestamp < pendingOracles[asset].validAt) {
            revert TimelockNotElapsed();
        }

        // Activate the pending oracle
        Oracle memory oracle = pendingOracles[asset].oracle;
        oracles[asset] = oracle;
        delete pendingOracles[asset];

        emit UpdateOracle(
            asset,
            oracle.aggregator,
            oracle.backupAggregator,
            oracle.maxPrice,
            oracle.minPrice,
            oracle.heartbeat,
            oracle.backupHeartbeat
        );
    }

    /**
     * @inheritdoc IOracleV1Plus
     */
    function revokePendingOracle(address asset) external onlyOwner {
        if (pendingOracles[asset].validAt == 0) {
            revert NoPendingValue();
        }
        delete pendingOracles[asset];
        emit RevokePendingOracle(asset);
    }

    /**
     * @inheritdoc IOracleV1Plus
     */
    function getPrice(address asset) external view override returns (uint256, uint8) {
        Oracle memory oracle = oracles[asset];

        if (oracle.aggregator == AggregatorV3Interface(address(0))) {
            revert InvalidAssetOrOracle();
        }

        // Try primary oracle first
        {
            (, int256 answer,, uint256 updatedAt,) = oracle.aggregator.latestRoundData();
            // Check if primary oracle is fresh and has positive price
            if (oracle.heartbeat == 0 || oracle.heartbeat + updatedAt >= block.timestamp) {
                if (_checkAnswer(answer, oracle)) {
                    return (uint256(answer), oracle.aggregator.decimals());
                }
            }
        }

        // Try backup oracle if available
        if (address(oracle.backupAggregator) != address(0)) {
            (, int256 answer,, uint256 updatedAt,) = oracle.backupAggregator.latestRoundData();
            // Check if backup oracle is fresh and has positive price
            if (oracle.backupHeartbeat == 0 || oracle.backupHeartbeat + updatedAt >= block.timestamp) {
                if (_checkAnswer(answer, oracle)) {
                    return (uint256(answer), oracle.backupAggregator.decimals());
                }
            }
        }

        // Both oracles failed or are stale
        revert OracleIsNotWorking(asset);
    }

    function _checkAnswer(int256 answer, Oracle memory oracle) internal pure returns (bool) {
        if (answer < 0) {
            return false; // Negative prices are invalid
        } else if (oracle.maxPrice != 0 && answer > oracle.maxPrice) {
            return false; // Price exceeds maximum cap
        } else if (oracle.minPrice != 0 && answer < oracle.minPrice) {
            return false; // Price is below minimum floor
        }
        return true; // Price is valid
    }
}
