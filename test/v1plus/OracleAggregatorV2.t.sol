// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {
    OracleAggregatorV1Plus,
    IOracleV1Plus,
    AggregatorV3Interface
} from "contracts/v1plus/oracle/OracleAggregatorV1Plus.sol";
import {MockPriceFeedV1Plus} from "contracts/v1plus/test/MockPriceFeedV1Plus.sol";

contract OracleAggregatorTestV1Plus is Test {
    OracleAggregatorV1Plus public oracleAggregator;
    MockPriceFeedV1Plus public primaryFeed;
    MockPriceFeedV1Plus public backupFeed;

    address public constant OWNER = address(0x1);
    address public constant ASSET = address(0x2);
    uint256 public constant TIMELOCK = 1 days;
    uint32 public constant HEARTBEAT = 1 hours;
    uint32 public constant BACKUP_HEARTBEAT = 2 hours;
    int256 public constant MAX_PRICE = 10000e8;
    int256 public constant MIN_PRICE = 1000e8;

    // Price feed configuration
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 3000e8;

    function setUp() public {
        // Deploy mock price feeds
        primaryFeed = new MockPriceFeedV1Plus(OWNER);
        backupFeed = new MockPriceFeedV1Plus(OWNER);

        // Set initial price data
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 1,
            answer: INITIAL_PRICE,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });

        vm.startPrank(OWNER);
        primaryFeed.updateRoundData(roundData);
        backupFeed.updateRoundData(roundData);
        vm.stopPrank();

        // Deploy OracleAggregator with owner and timelock
        vm.prank(OWNER);
        oracleAggregator = new OracleAggregatorV1Plus(OWNER, TIMELOCK);
    }

    function test_SubmitPendingOracle() public {
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.prank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);

        // Access the Oracle struct directly from the mapping
        (
            AggregatorV3Interface aggregator,
            AggregatorV3Interface backupAggregator,
            int256 maxPrice,
            int256 minPrice,
            uint32 heartbeat,
            uint32 backupHeartbeat
        ) = oracleAggregator.oracles(ASSET);
        assertEq(address(aggregator), address(0), "Oracle should not be set yet");
        assertEq(address(backupAggregator), address(0), "Backup oracle should not be set yet");
        assertEq(heartbeat, 0, "Heartbeat should not be set yet");
        assertEq(backupHeartbeat, 0, "Backup heartbeat should not be set yet");
        assertEq(maxPrice, 0, "Max price should not be set yet");
        assertEq(minPrice, 0, "Min price should not be set yet");

        (IOracleV1Plus.Oracle memory pendingOracle, uint64 validAt) = oracleAggregator.pendingOracles(ASSET);
        assertEq(address(pendingOracle.aggregator), address(primaryFeed));
        assertEq(address(pendingOracle.backupAggregator), address(backupFeed));
        assertEq(pendingOracle.heartbeat, HEARTBEAT);
        assertEq(pendingOracle.backupHeartbeat, BACKUP_HEARTBEAT);
        assertEq(pendingOracle.maxPrice, MAX_PRICE);
        assertEq(validAt, block.timestamp + TIMELOCK);
    }

    function test_AcceptPendingOracle() public {
        // Submit pending oracle
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.prank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);

        // Warp time past timelock
        vm.warp(block.timestamp + TIMELOCK + 1);

        oracleAggregator.acceptPendingOracle(ASSET);

        // Access the Oracle struct directly from the mapping
        (
            AggregatorV3Interface aggregator,
            AggregatorV3Interface backupAggregator,
            int256 maxPrice,
            int256 minPrice,
            uint32 heartbeat,
            uint32 backupHeartbeat
        ) = oracleAggregator.oracles(ASSET);
        assertEq(address(aggregator), address(primaryFeed));
        assertEq(address(backupAggregator), address(backupFeed));
        assertEq(heartbeat, HEARTBEAT);
        assertEq(backupHeartbeat, BACKUP_HEARTBEAT);
        assertEq(maxPrice, MAX_PRICE);
        assertEq(minPrice, MIN_PRICE);

        // Verify pending oracle is cleared
        (IOracleV1Plus.Oracle memory pendingOracle, uint64 validAt) = oracleAggregator.pendingOracles(ASSET);
        assertEq(address(pendingOracle.aggregator), address(0));
        assertEq(address(pendingOracle.backupAggregator), address(0));
        assertEq(pendingOracle.heartbeat, 0);
        assertEq(pendingOracle.backupHeartbeat, 0);
        assertEq(pendingOracle.maxPrice, 0);
        assertEq(validAt, 0);
    }

    function test_GetPrice_PrimaryOracle() public {
        // Setup oracle
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Update primary oracle timestamp to match current time
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 1,
            answer: INITIAL_PRICE,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
        vm.prank(OWNER);
        primaryFeed.updateRoundData(roundData);

        // Get price
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(INITIAL_PRICE));
        assertEq(decimals, DECIMALS);
    }

    function test_GetPrice_FallbackToBackup() public {
        // Setup oracle
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Make primary oracle stale
        vm.warp(block.timestamp + HEARTBEAT + 1);

        // Update backup price
        int256 backupPrice = 3100e8;
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: backupPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        backupFeed.updateRoundData(roundData);

        // Get price - should use backup
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(backupPrice));
        assertEq(decimals, DECIMALS);
    }

    function test_RevertGetPrice_BothOraclesStale() public {
        // Setup oracle
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Make both oracles stale
        vm.warp(block.timestamp + HEARTBEAT + 1);

        vm.expectRevert(abi.encodeWithSignature("OracleIsNotWorking(address)", ASSET));
        // Should revert
        oracleAggregator.getPrice(ASSET);
    }

    function test_RevertSubmitPendingOracle_NotOwner() public {
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.prank(address(0x3));
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(0x3)));
        oracleAggregator.submitPendingOracle(ASSET, oracle);
    }

    function test_RevertAcceptPendingOracle_BeforeTimelock() public {
        // Submit pending oracle
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.prank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.expectRevert(abi.encodeWithSignature("TimelockNotElapsed()"));
        // Try to accept before timelock expires
        oracleAggregator.acceptPendingOracle(ASSET);
    }

    function test_RemoveOracle() public {
        // First add an oracle
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Now remove it by submitting empty oracle
        vm.prank(OWNER);
        oracleAggregator.submitPendingOracle(
            ASSET,
            IOracleV1Plus.Oracle({
                aggregator: AggregatorV3Interface(address(0)),
                backupAggregator: AggregatorV3Interface(address(0)),
                heartbeat: 0,
                backupHeartbeat: 0,
                maxPrice: 0,
                minPrice: 0
            })
        );

        // Verify oracle is removed
        (
            AggregatorV3Interface aggregator,
            AggregatorV3Interface backupAggregator,
            int256 maxPrice,
            int256 minPrice,
            uint32 heartbeat,
            uint32 backupHeartbeat
        ) = oracleAggregator.oracles(ASSET);
        assertEq(address(aggregator), address(0));
        assertEq(address(backupAggregator), address(0));
        assertEq(heartbeat, 0);
        assertEq(backupHeartbeat, 0);
        assertEq(maxPrice, 0);
        assertEq(minPrice, 0);
    }

    function test_GetPrice_PrimaryExceedsMaxPrice_NoBackup() public {
        // Create an oracle with maxPrice and no backup
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: AggregatorV3Interface(address(0)),
            heartbeat: HEARTBEAT,
            backupHeartbeat: 0,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set primary price above maxPrice
        int256 highPrice = MAX_PRICE + 1000e8;
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: highPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        primaryFeed.updateRoundData(roundData);

        // Should revert since primary exceeds maxPrice and no backup exists
        vm.expectRevert(abi.encodeWithSignature("OracleIsNotWorking(address)", ASSET));
        oracleAggregator.getPrice(ASSET);
    }

    function test_GetPrice_PrimaryExceedsMaxPrice_WithBackup() public {
        // Create an oracle with maxPrice
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set primary price above maxPrice
        int256 highPrice = MAX_PRICE + 1000e8;
        MockPriceFeedV1Plus.RoundData memory primaryRoundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: highPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });

        // Set backup price below maxPrice (valid)
        int256 backupPrice = MAX_PRICE - 1000e8;
        MockPriceFeedV1Plus.RoundData memory backupRoundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: backupPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });

        vm.startPrank(OWNER);
        primaryFeed.updateRoundData(primaryRoundData);
        backupFeed.updateRoundData(backupRoundData);
        vm.stopPrank();

        // Get price - should fallback to backup oracle since primary exceeds maxPrice
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(backupPrice));
        assertEq(decimals, DECIMALS);
    }

    function test_RevertGetPrice_BothExceedMaxPrice() public {
        // Create an oracle with maxPrice
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set both primary and backup prices above maxPrice
        int256 highPrimaryPrice = MAX_PRICE + 1000e8;
        MockPriceFeedV1Plus.RoundData memory primaryRoundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: highPrimaryPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });

        int256 highBackupPrice = MAX_PRICE + 500e8;
        MockPriceFeedV1Plus.RoundData memory backupRoundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: highBackupPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });

        vm.startPrank(OWNER);
        primaryFeed.updateRoundData(primaryRoundData);
        backupFeed.updateRoundData(backupRoundData);
        vm.stopPrank();

        // Should revert since both oracles exceed maxPrice
        vm.expectRevert(abi.encodeWithSignature("OracleIsNotWorking(address)", ASSET));
        oracleAggregator.getPrice(ASSET);
    }

    function test_GetPrice_WithMaxPriceZero_PrimaryOracle() public {
        // Create an oracle with maxPrice set to 0 (no price cap)
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: 0, // No price cap
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set very high price that would normally exceed any reasonable cap
        int256 extremelyHighPrice = 1000000e8; // 1 million units
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: extremelyHighPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        primaryFeed.updateRoundData(roundData);

        // Get price - should return the full price without capping
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(extremelyHighPrice));
        assertEq(decimals, DECIMALS);
    }

    function test_GetPrice_WithMaxPriceZero_FallbackToBackup() public {
        // Create an oracle with maxPrice set to 0 (no price cap)
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: 0, // No price cap
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Make primary oracle stale
        vm.warp(block.timestamp + HEARTBEAT + 1);

        // Set very high price on backup oracle
        int256 extremelyHighBackupPrice = 2000000e8; // 2 million units
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: extremelyHighBackupPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        backupFeed.updateRoundData(roundData);

        // Get price - should return the full backup price without capping
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(extremelyHighBackupPrice));
        assertEq(decimals, DECIMALS);
    }

    // ========== MIN PRICE TESTS ==========

    function test_GetPrice_PrimaryBelowMinPrice_WithBackup() public {
        // Create an oracle with minPrice
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set primary price below minPrice
        int256 lowPrice = MIN_PRICE - 1000e8;
        MockPriceFeedV1Plus.RoundData memory primaryRoundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: lowPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });

        // Set backup price above minPrice
        int256 validBackupPrice = MIN_PRICE + 1000e8;
        MockPriceFeedV1Plus.RoundData memory backupRoundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: validBackupPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });

        vm.startPrank(OWNER);
        primaryFeed.updateRoundData(primaryRoundData);
        backupFeed.updateRoundData(backupRoundData);
        vm.stopPrank();

        // Get price - should fallback to backup oracle
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(validBackupPrice));
        assertEq(decimals, DECIMALS);
    }

    function test_GetPrice_PriceAtMinPrice() public {
        // Create an oracle with minPrice
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set price exactly at minPrice
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: MIN_PRICE,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        primaryFeed.updateRoundData(roundData);

        // Get price - should return the exact minPrice
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(MIN_PRICE));
        assertEq(decimals, DECIMALS);
    }

    function test_RevertGetPrice_CombinedMaxMinPriceConstraints() public {
        // Create an oracle with both maxPrice and minPrice
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Test price below minPrice should revert when no valid backup
        int256 lowPrice = MIN_PRICE - 100e8;
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: lowPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });

        // Set both primary and backup to invalid prices
        vm.startPrank(OWNER);
        primaryFeed.updateRoundData(roundData);
        backupFeed.updateRoundData(roundData);
        vm.stopPrank();

        // Should revert since both oracles are below minPrice
        vm.expectRevert(abi.encodeWithSignature("OracleIsNotWorking(address)", ASSET));
        oracleAggregator.getPrice(ASSET);

        // Test price above maxPrice should revert when no valid backup
        int256 highPrice = MAX_PRICE + 1000e8;
        roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 3,
            answer: highPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 3
        });

        vm.startPrank(OWNER);
        primaryFeed.updateRoundData(roundData);
        backupFeed.updateRoundData(roundData);
        vm.stopPrank();

        // Should revert since both oracles exceed maxPrice
        vm.expectRevert(abi.encodeWithSignature("OracleIsNotWorking(address)", ASSET));
        oracleAggregator.getPrice(ASSET);

        // Test price within range is unchanged
        int256 validPrice = (MIN_PRICE + MAX_PRICE) / 2; // Middle value
        roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 4,
            answer: validPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 4
        });
        vm.prank(OWNER);
        primaryFeed.updateRoundData(roundData);

        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(validPrice));
        assertEq(decimals, DECIMALS);
    }

    function test_GetPrice_NoBackupAggregator() public {
        // Create an oracle with no backup aggregator
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: AggregatorV3Interface(address(0)),
            heartbeat: HEARTBEAT,
            backupHeartbeat: 0,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set normal price
        int256 newPrice = 3200e8;
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: newPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        primaryFeed.updateRoundData(roundData);

        // Get price - should return the primary price
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(newPrice));
        assertEq(decimals, DECIMALS);
    }

    function test_RevertGetPrice_NoBackupAggregator_PrimaryStale() public {
        // Create an oracle with no backup aggregator
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: AggregatorV3Interface(address(0)),
            heartbeat: HEARTBEAT,
            backupHeartbeat: 0,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Make primary oracle stale
        vm.warp(block.timestamp + HEARTBEAT + 1);

        // Should revert since primary is stale and no backup exists
        vm.expectRevert(abi.encodeWithSignature("OracleIsNotWorking(address)", ASSET));
        oracleAggregator.getPrice(ASSET);
    }

    function test_RevertSubmitPendingOracle_DecimalMismatch() public {
        // Create another mock feed with different decimals
        MockPriceFeedV1Plus differentDecimalsFeed = new MockPriceFeedV1Plus(OWNER);
        vm.startPrank(OWNER);
        differentDecimalsFeed.setDecimals(DECIMALS + 2); // Different decimal precision

        // Set initial price data on the different decimals feed
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 1,
            answer: INITIAL_PRICE,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
        differentDecimalsFeed.updateRoundData(roundData);
        vm.stopPrank();

        // Try to set an oracle with mismatched decimals
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: differentDecimalsFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("InvalidAssetOrOracle()"));
        oracleAggregator.submitPendingOracle(ASSET, oracle);
    }

    function test_RevokePendingOracle() public {
        // First submit a pending oracle
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.prank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);

        // Verify the pending oracle was set
        (IOracleV1Plus.Oracle memory pendingOracle, uint64 validAt) = oracleAggregator.pendingOracles(ASSET);
        assertEq(address(pendingOracle.aggregator), address(primaryFeed));
        assertEq(validAt, block.timestamp + TIMELOCK);

        // Now revoke it
        vm.prank(OWNER);
        oracleAggregator.revokePendingOracle(ASSET);

        // Verify it was revoked
        (pendingOracle, validAt) = oracleAggregator.pendingOracles(ASSET);
        assertEq(address(pendingOracle.aggregator), address(0));
        assertEq(validAt, 0);
    }

    function test_RevertRevokePendingOracle_NoPending() public {
        // Try to revoke when there's no pending oracle
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSignature("NoPendingValue()"));
        oracleAggregator.revokePendingOracle(ASSET);
    }

    function test_RevertRevokePendingOracle_NotOwner() public {
        // First submit a pending oracle
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.prank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);

        // Try to revoke from non-owner account
        address nonOwner = address(0x123);
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        oracleAggregator.revokePendingOracle(ASSET);
    }

    // ========== MIN PRICE TESTS ==========

    function test_GetPrice_PrimaryBelowMinPrice_NoBackup() public {
        // Create an oracle with minPrice and no backup
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: AggregatorV3Interface(address(0)),
            heartbeat: HEARTBEAT,
            backupHeartbeat: 0,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set primary price below minPrice
        int256 lowPrice = MIN_PRICE - 100e8;
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: lowPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        primaryFeed.updateRoundData(roundData);

        // Should revert since primary is below minPrice and no backup exists
        vm.expectRevert(abi.encodeWithSignature("OracleIsNotWorking(address)", ASSET));
        oracleAggregator.getPrice(ASSET);
    }

    function test_GetPrice_BothBelowMinPrice() public {
        // Create an oracle with minPrice
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set both primary and backup prices below minPrice
        int256 lowPrimaryPrice = MIN_PRICE - 1000e8;
        MockPriceFeedV1Plus.RoundData memory primaryRoundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: lowPrimaryPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });

        int256 lowBackupPrice = MIN_PRICE - 500e8;
        MockPriceFeedV1Plus.RoundData memory backupRoundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: lowBackupPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });

        vm.startPrank(OWNER);
        primaryFeed.updateRoundData(primaryRoundData);
        backupFeed.updateRoundData(backupRoundData);
        vm.stopPrank();

        // Should revert since both oracles are below minPrice
        vm.expectRevert(abi.encodeWithSignature("OracleIsNotWorking(address)", ASSET));
        oracleAggregator.getPrice(ASSET);
    }

    function test_GetPrice_WithMinPriceZero_PrimaryOracle() public {
        // Create an oracle with minPrice set to 0 (no price floor)
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: 0 // No price floor
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set very low price that would normally be below any reasonable floor
        int256 extremelyLowPrice = 1e8; // 1 unit
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: extremelyLowPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        primaryFeed.updateRoundData(roundData);

        // Get price - should return the full price without flooring
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(extremelyLowPrice));
        assertEq(decimals, DECIMALS);
    }

    function test_GetPrice_WithMinPriceZero_FallbackToBackup() public {
        // Create an oracle with minPrice set to 0 (no price floor)
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: 0 // No price floor
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Make primary oracle stale
        vm.warp(block.timestamp + HEARTBEAT + 1);

        // Set very low price on backup oracle
        int256 extremelyLowBackupPrice = 5e7; // 0.5 units
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: extremelyLowBackupPrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        backupFeed.updateRoundData(roundData);

        // Get price - should return the full backup price without flooring
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(extremelyLowBackupPrice));
        assertEq(decimals, DECIMALS);
    }

    function test_GetPrice_PriceJustAboveMinPrice() public {
        // Create an oracle with minPrice
        IOracleV1Plus.Oracle memory oracle = IOracleV1Plus.Oracle({
            aggregator: primaryFeed,
            backupAggregator: backupFeed,
            heartbeat: HEARTBEAT,
            backupHeartbeat: BACKUP_HEARTBEAT,
            maxPrice: MAX_PRICE,
            minPrice: MIN_PRICE
        });

        vm.startPrank(OWNER);
        oracleAggregator.submitPendingOracle(ASSET, oracle);
        vm.warp(block.timestamp + TIMELOCK + 1);
        vm.stopPrank();

        oracleAggregator.acceptPendingOracle(ASSET);

        // Set price just above minPrice
        int256 priceAboveMin = MIN_PRICE + 1;
        MockPriceFeedV1Plus.RoundData memory roundData = MockPriceFeedV1Plus.RoundData({
            roundId: 2,
            answer: priceAboveMin,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 2
        });
        vm.prank(OWNER);
        primaryFeed.updateRoundData(roundData);

        // Get price - should return the actual price without modification
        (uint256 price, uint8 decimals) = oracleAggregator.getPrice(ASSET);
        assertEq(price, uint256(priceAboveMin));
        assertEq(decimals, DECIMALS);
    }
}
