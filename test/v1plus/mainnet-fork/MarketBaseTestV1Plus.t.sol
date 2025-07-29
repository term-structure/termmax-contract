// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {DeployUtils} from "../utils/DeployUtils.sol";
import {JSONLoader} from "../utils/JSONLoader.sol";
import {StateChecker} from "../utils/StateChecker.sol";
import {SwapUtils} from "../utils/SwapUtils.sol";
import {ForkBaseTestV1Plus} from "./ForkBaseTestV1Plus.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TermMaxFactoryV1Plus, ITermMaxFactory} from "contracts/v1plus/factory/TermMaxFactoryV1Plus.sol";
import {ITermMaxRouterV1Plus, TermMaxRouterV1Plus} from "contracts/v1plus/router/TermMaxRouterV1Plus.sol";
import {TermMaxMarketV1Plus, Constants, SafeCast, MarketEvents} from "contracts/v1plus/TermMaxMarketV1Plus.sol";
import {TermMaxOrderV1Plus, OrderConfig} from "contracts/v1plus/TermMaxOrderV1Plus.sol";
import {MockERC20} from "contracts/v1/test/MockERC20.sol";
import {MockPriceFeed} from "contracts/v1/test/MockPriceFeed.sol";
import {MockOrderV1Plus} from "contracts/v1plus/test/MockOrderV1Plus.sol";
import {MintableERC20V1Plus} from "contracts/v1plus/tokens/MintableERC20V1Plus.sol";
import {IMintableERC20} from "contracts/v1/tokens/IMintableERC20.sol";
import {SwapAdapter} from "contracts/v1/test/testnet/SwapAdapter.sol";
import {IOracleV1Plus, OracleAggregatorV1Plus} from "contracts/v1plus/oracle/OracleAggregatorV1Plus.sol";
import {IOracle} from "contracts/v1/oracle/IOracle.sol";
import {IOrderManager, OrderManager} from "contracts/v1/vault/OrderManager.sol";
import {ITermMaxVault, ITermMaxVaultV1Plus, TermMaxVaultV1Plus} from "contracts/v1plus/vault/TermMaxVaultV1Plus.sol";
import {VaultFactory, IVaultFactory} from "contracts/v1/factory/VaultFactory.sol";
import {
    MarketConfig,
    FeeConfig,
    MarketInitialParams,
    LoanConfig,
    VaultInitialParams
} from "contracts/v1/storage/TermMaxStorage.sol";
import {ITermMaxRouter, RouterEvents, RouterErrors} from "contracts/v1/router/TermMaxRouter.sol";
import {MockFlashLoanReceiver} from "contracts/v1/test/MockFlashLoanReceiver.sol";
import {SwapUnit, ISwapAdapter} from "contracts/v1/router/ISwapAdapter.sol";
import {
    IGearingToken,
    IGearingTokenV1Plus,
    GearingTokenWithERC20V1Plus
} from "contracts/v1plus/tokens/GearingTokenWithERC20V1Plus.sol";
import {MintableERC20V1Plus} from "contracts/v1plus/tokens/MintableERC20V1Plus.sol";
import {ITermMaxOrder} from "contracts/v1/ITermMaxOrder.sol";
import {ISwapCallback} from "contracts/v1/ISwapCallback.sol";
import {UniswapV3AdapterV1Plus} from "contracts/v1plus/router/swapAdapters/UniswapV3AdapterV1Plus.sol";
import {PendleSwapV3AdapterV1Plus} from "contracts/v1plus/router/swapAdapters/PendleSwapV3AdapterV1Plus.sol";
import {OdosV2AdapterV1Plus} from "contracts/v1plus/router/swapAdapters/OdosV2AdapterV1Plus.sol";
import {ERC4626VaultAdapterV1Plus} from "contracts/v1plus/router/swapAdapters/ERC4626VaultAdapterV1Plus.sol";
import {KyberswapV2AdapterV1Plus} from "contracts/v1plus/router/swapAdapters/KyberswapV2AdapterV1Plus.sol";

abstract contract MarketBaseTestV1Plus is ForkBaseTestV1Plus {
    using SafeCast for *;

    struct MarketTestRes {
        uint256 blockNumber;
        uint256 orderInitialAmount;
        MarketInitialParams marketInitialParams;
        OrderConfig orderConfig;
        TermMaxMarketV1Plus market;
        IMintableERC20 ft;
        IMintableERC20 xt;
        IGearingToken gt;
        IERC20Metadata collateral;
        IERC20Metadata debtToken;
        IOracleV1Plus oracle;
        MockPriceFeed collateralPriceFeed;
        MockPriceFeed debtPriceFeed;
        ITermMaxOrder order;
        ITermMaxRouterV1Plus router;
        uint256 maxXtReserve;
        address maker;
    }

    function _initializeMarketTestRes(string memory key) internal returns (MarketTestRes memory) {
        MarketTestRes memory res;
        res.blockNumber = _readBlockNumber(key);
        res.marketInitialParams = _readMarketInitialParams(key);
        res.orderConfig = _readOrderConfig(key);
        res.maker = vm.randomAddress();
        res.maxXtReserve = type(uint128).max;

        vm.rollFork(res.blockNumber);

        vm.startPrank(res.marketInitialParams.admin);

        res.oracle = deployOracleAggregator(res.marketInitialParams.admin);
        res.collateralPriceFeed = deployMockPriceFeed(res.marketInitialParams.admin);
        res.debtPriceFeed = deployMockPriceFeed(res.marketInitialParams.admin);
        res.oracle.submitPendingOracle(
            address(res.marketInitialParams.collateral),
            IOracleV1Plus.Oracle(res.collateralPriceFeed, res.collateralPriceFeed, 0, 0, 0, 0)
        );
        res.oracle.submitPendingOracle(
            address(res.marketInitialParams.debtToken),
            IOracleV1Plus.Oracle(res.debtPriceFeed, res.debtPriceFeed, 0, 0, 0, 0)
        );
        res.oracle.acceptPendingOracle(address(res.marketInitialParams.collateral));
        res.oracle.acceptPendingOracle(address(res.marketInitialParams.debtToken));

        res.marketInitialParams.marketConfig.maturity += uint64(block.timestamp);
        res.marketInitialParams.loanConfig.oracle = IOracle(address(res.oracle));

        res.market = TermMaxMarketV1Plus(
            deployFactory(res.marketInitialParams.admin).createMarket(
                keccak256("GearingTokenWithERC20"), res.marketInitialParams, 0
            )
        );

        (res.ft, res.xt, res.gt,,) = res.market.tokens();
        res.debtToken = res.marketInitialParams.debtToken;
        res.collateral = IERC20Metadata(res.marketInitialParams.collateral);

        // set all price as 1 USD = 1e8 tokens
        uint8 debtDecimals = res.debtToken.decimals();
        _setPriceFeedInTokenDecimal8(
            res.debtPriceFeed, debtDecimals, MockPriceFeed.RoundData(1, 1e8, block.timestamp, block.timestamp, 0)
        );
        uint8 collateralDecimals = res.collateral.decimals();
        _setPriceFeedInTokenDecimal8(
            res.collateralPriceFeed,
            collateralDecimals,
            MockPriceFeed.RoundData(1, 1e8, block.timestamp, block.timestamp, 0)
        );

        res.order =
            res.market.createOrder(res.maker, res.maxXtReserve, ISwapCallback(address(0)), res.orderConfig.curveCuts);

        res.router = deployRouter(res.marketInitialParams.admin);

        res.orderInitialAmount = vm.parseJsonUint(jsonData, string.concat(key, ".orderInitialAmount"));
        deal(address(res.debtToken), res.marketInitialParams.admin, res.orderInitialAmount);

        res.debtToken.approve(address(res.market), res.orderInitialAmount);
        res.market.mint(address(res.order), res.orderInitialAmount);

        vm.stopPrank();

        return res;
    }

    function _testMint(MarketTestRes memory res) internal {
        address to = vm.randomAddress();
        uint256 amount = 100e8;
        deal(address(res.debtToken), to, amount);
        deal(to, 1e18);
        vm.startPrank(to);
        res.debtToken.approve(address(res.market), amount);
        res.market.mint(to, amount);
        vm.assertEq(res.ft.balanceOf(to), amount);
        vm.assertEq(res.xt.balanceOf(to), amount);
        vm.stopPrank();
    }

    function _testBurn(MarketTestRes memory res) internal {
        address taker = vm.randomAddress();
        uint256 amount = 100e8;
        deal(taker, 1e18);
        deal(address(res.debtToken), taker, amount);
        vm.startPrank(taker);
        res.debtToken.approve(address(res.market), amount);
        res.market.mint(taker, amount);

        res.market.burn(taker, taker, amount);
        vm.assertEq(res.debtToken.balanceOf(taker), amount);
        vm.stopPrank();
    }

    function _testRedeem(MarketTestRes memory res) internal {
        MarketConfig memory marketConfig = res.market.config();
        vm.prank(res.marketInitialParams.admin);
        res.market.updateMarketConfig(marketConfig);

        address bob = vm.randomAddress();
        address alice = vm.randomAddress();
        deal(bob, 1e18);
        deal(alice, 1e18);

        uint128 depositAmt = uint128(res.orderInitialAmount);
        uint128 debtAmt = uint128(res.orderInitialAmount / 20);
        uint256 collateralAmt = uint256(res.orderInitialAmount / 10);

        vm.startPrank(bob);
        deal(address(res.debtToken), bob, depositAmt);
        res.debtToken.approve(address(res.market), depositAmt);
        res.market.mint(bob, depositAmt);

        res.xt.transfer(alice, debtAmt);
        vm.stopPrank();

        vm.startPrank(alice);

        MockFlashLoanReceiver receiver = new MockFlashLoanReceiver(res.market);
        deal(address(res.collateral), address(receiver), collateralAmt);

        res.xt.approve(address(receiver), debtAmt);
        receiver.leverageByXt(debtAmt, abi.encode(alice, collateralAmt));
        vm.stopPrank();

        vm.warp(marketConfig.maturity + Constants.LIQUIDATION_WINDOW);

        vm.startPrank(bob);
        res.ft.approve(address(res.market), depositAmt);

        uint256 propotion =
            depositAmt * Constants.DECIMAL_BASE_SQ / (res.ft.totalSupply() - res.ft.balanceOf(address(res.market)));
        uint256 redeemAmt = propotion * res.debtToken.balanceOf(address(res.market)) / Constants.DECIMAL_BASE_SQ;
        uint256 redeemedCollateral = propotion * res.collateral.balanceOf(address(res.gt)) / Constants.DECIMAL_BASE_SQ;

        vm.expectEmit();
        emit MarketEvents.Redeem(bob, bob, uint128(propotion), uint128(redeemAmt), abi.encode(redeemedCollateral));
        res.market.redeem(bob, bob, depositAmt);

        assertEq(res.debtToken.balanceOf(bob), redeemAmt);
        assertEq(res.collateral.balanceOf(bob), redeemedCollateral);
        assertEq(res.ft.balanceOf(bob), 0);
        vm.stopPrank();
    }

    function _testIssueFtByGtWhenSwap(MarketTestRes memory res, uint256 collateralAmt, uint128 debtAmt) internal {
        address taker = vm.randomAddress();
        deal(taker, 1e18);

        uint128 ftOutAmt = 151e8;
        uint128 maxTokenIn = 150e8;

        vm.startPrank(res.maker);
        deal(res.maker, 1e18);
        deal(address(res.collateral), res.maker, collateralAmt);
        res.collateral.approve(address(res.gt), collateralAmt);
        (uint256 gtId,) = res.market.issueFt(res.maker, debtAmt, abi.encode(collateralAmt));

        res.gt.approve(address(res.order), gtId);
        OrderConfig memory orderConfig = res.order.orderConfig();
        orderConfig.gtId = gtId;
        // make sure ft reserve in order is zero and xt is 150e8
        res.order.updateOrder(
            orderConfig,
            -(res.ft.balanceOf(address(res.order)).toInt256()),
            -(res.xt.balanceOf(address(res.order)) - maxTokenIn).toInt256()
        );
        vm.stopPrank();

        vm.startPrank(taker);
        deal(address(res.debtToken), taker, maxTokenIn);
        res.debtToken.approve(address(res.order), maxTokenIn);
        res.order.swapTokenToExactToken(res.debtToken, res.ft, taker, ftOutAmt, maxTokenIn, block.timestamp + 1 hours);
        assertEq(res.ft.balanceOf(taker), ftOutAmt);
        (, uint128 debtAmtNow,) = res.gt.loanInfo(gtId);
        assertGt(debtAmtNow, debtAmt);
        vm.stopPrank();
    }
}
