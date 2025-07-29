// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ITermMaxMarket, ITermMaxMarketV1Plus, TermMaxMarketV1Plus} from "contracts/v1plus/TermMaxMarketV1Plus.sol";
import {ITermMaxOrder, ISwapCallback, TermMaxOrderV1Plus} from "contracts/v1plus/TermMaxOrderV1Plus.sol";
import {MockERC20, ERC20} from "contracts/v1/test/MockERC20.sol";
import {MockPriceFeed} from "contracts/v1/test/MockPriceFeed.sol";
import {IMintableERC20} from "contracts/v1/tokens/IMintableERC20.sol";
import {IMintableERC20V1Plus, MintableERC20V1Plus} from "contracts/v1plus/tokens/MintableERC20V1Plus.sol";
import {IGearingToken} from "contracts/v1/tokens/IGearingToken.sol";
import {ITermMaxFactory, TermMaxFactoryV1Plus} from "contracts/v1plus/factory/TermMaxFactoryV1Plus.sol";
import {TermMaxRouterV1Plus} from "contracts/v1plus/router/TermMaxRouterV1Plus.sol";
import {
    IOracleV1Plus,
    OracleAggregatorV1Plus,
    AggregatorV3Interface
} from "contracts/v1plus/oracle/OracleAggregatorV1Plus.sol";
import {IOracle} from "contracts/v1/oracle/IOracle.sol";
import {MockOrderV1Plus} from "contracts/v1plus/test/MockOrderV1Plus.sol";
import {VaultFactory, IVaultFactory} from "contracts/v1/factory/VaultFactory.sol";
import {OrderManagerV1Plus} from "contracts/v1plus/vault/OrderManagerV1Plus.sol";
import {TermMaxVaultV1Plus, ITermMaxVault} from "contracts/v1plus/vault/TermMaxVaultV1Plus.sol";
import {AccessManager} from "contracts/v1plus/access/AccessManagerV1Plus.sol";
import {
    VaultInitialParams,
    MarketConfig,
    MarketInitialParams,
    LoanConfig,
    OrderConfig,
    CurveCut,
    CurveCuts
} from "contracts/v1/storage/TermMaxStorage.sol";
import {VaultInitialParamsV1Plus} from "contracts/v1plus/storage/TermMaxStorageV1Plus.sol";
import {TermMaxVaultFactoryV1Plus} from "contracts/v1plus/factory/TermMaxVaultFactoryV1Plus.sol";

library DeployUtils {
    bytes32 constant GT_ERC20 = keccak256("GearingTokenWithERC20");

    struct SwapRange {
        uint256 buyFtMax;
        uint256 buyXtMax;
        uint256 sellFtMax;
        uint256 sellXtMax;
        uint256 buyExactFtMax;
        uint256 buyExactXtMax;
        uint256 sellFtForExactTokenMax;
        uint256 sellXtForExactTokenMax;
    }

    struct Res {
        ITermMaxVault vault;
        IVaultFactory vaultFactory;
        TermMaxFactoryV1Plus factory;
        ITermMaxOrder order;
        TermMaxRouterV1Plus router;
        MarketConfig marketConfig;
        OrderConfig orderConfig;
        ITermMaxMarket market;
        IMintableERC20 ft;
        IMintableERC20 xt;
        IGearingToken gt;
        MockPriceFeed debtOracle;
        MockPriceFeed collateralOracle;
        OracleAggregatorV1Plus oracle;
        MockERC20 collateral;
        MockERC20 debt;
        SwapRange swapRange;
    }

    function deployMarket(address admin, MarketConfig memory marketConfig, uint32 maxLtv, uint32 liquidationLtv)
        internal
        returns (Res memory res)
    {
        res.factory = deployFactory(admin);

        res.collateral = new MockERC20("ETH", "ETH", 18);
        res.debt = new MockERC20("DAI", "DAI", 8);

        res.debtOracle = new MockPriceFeed(admin);
        res.collateralOracle = new MockPriceFeed(admin);
        res.oracle = deployOracle(admin, 0);

        res.oracle.submitPendingOracle(
            address(res.debt), IOracleV1Plus.Oracle(res.debtOracle, res.debtOracle, 0, 0, 365 days, 0)
        );
        res.oracle.submitPendingOracle(
            address(res.collateral), IOracleV1Plus.Oracle(res.collateralOracle, res.collateralOracle, 0, 0, 365 days, 0)
        );

        res.oracle.acceptPendingOracle(address(res.debt));
        res.oracle.acceptPendingOracle(address(res.collateral));

        MockPriceFeed.RoundData memory roundData = MockPriceFeed.RoundData({
            roundId: 1,
            answer: int256(1e1 ** res.collateralOracle.decimals()),
            startedAt: 0,
            updatedAt: 0,
            answeredInRound: 0
        });
        res.collateralOracle.updateRoundData(roundData);

        MarketInitialParams memory initialParams = MarketInitialParams({
            collateral: address(res.collateral),
            debtToken: res.debt,
            admin: admin,
            gtImplementation: address(0),
            marketConfig: marketConfig,
            loanConfig: LoanConfig({
                oracle: IOracle(address(res.oracle)),
                liquidationLtv: liquidationLtv,
                maxLtv: maxLtv,
                liquidatable: true
            }),
            gtInitalParams: abi.encode(type(uint256).max),
            tokenName: "DAI-ETH",
            tokenSymbol: "DAI-ETH"
        });

        res.marketConfig = marketConfig;
        res.market = ITermMaxMarket(res.factory.createMarket(GT_ERC20, initialParams, 0));

        (res.ft, res.xt, res.gt,,) = res.market.tokens();
    }

    function deployMarket(
        address admin,
        MarketConfig memory marketConfig,
        uint32 maxLtv,
        uint32 liquidationLtv,
        address collateral,
        address debt
    ) internal returns (Res memory res) {
        res.factory = deployFactory(admin);

        res.collateral = MockERC20(collateral);
        res.debt = MockERC20(debt);

        res.debtOracle = new MockPriceFeed(admin);
        res.collateralOracle = new MockPriceFeed(admin);
        res.oracle = deployOracle(admin, 0);

        res.oracle.submitPendingOracle(
            address(res.debt), IOracleV1Plus.Oracle(res.debtOracle, res.debtOracle, 0, 0, 365 days, 0)
        );
        res.oracle.submitPendingOracle(
            address(res.collateral), IOracleV1Plus.Oracle(res.collateralOracle, res.collateralOracle, 0, 0, 365 days, 0)
        );
        res.oracle.acceptPendingOracle(address(res.debt));
        res.oracle.acceptPendingOracle(address(res.collateral));

        MockPriceFeed.RoundData memory roundData = MockPriceFeed.RoundData({
            roundId: 1,
            answer: int256(1e1 ** res.collateralOracle.decimals()),
            startedAt: 0,
            updatedAt: 0,
            answeredInRound: 0
        });
        res.collateralOracle.updateRoundData(roundData);

        MarketInitialParams memory initialParams = MarketInitialParams({
            collateral: address(res.collateral),
            debtToken: res.debt,
            admin: admin,
            gtImplementation: address(0),
            marketConfig: marketConfig,
            loanConfig: LoanConfig({
                oracle: IOracle(address(res.oracle)),
                liquidationLtv: liquidationLtv,
                maxLtv: maxLtv,
                liquidatable: true
            }),
            gtInitalParams: abi.encode(type(uint256).max),
            tokenName: "DAI-ETH",
            tokenSymbol: "DAI-ETH"
        });

        res.marketConfig = marketConfig;
        res.market = ITermMaxMarket(res.factory.createMarket(GT_ERC20, initialParams, 0));

        (res.ft, res.xt, res.gt,,) = res.market.tokens();
    }

    function deployMockMarket2(
        address admin,
        IERC20 debt,
        uint256 duration,
        MarketConfig memory mc,
        uint32 maxLtv,
        uint32 liquidationLtv
    ) internal returns (Res memory res) {
        res.factory = deployFactoryWithMockOrder(admin);
        res.debt = MockERC20(address(debt));
        MarketConfig memory marketConfig = mc;
        marketConfig.maturity += uint64(duration * 1 days);

        res.collateral = new MockERC20("ETH", "ETH", 18);

        res.debtOracle = new MockPriceFeed(admin);
        res.collateralOracle = new MockPriceFeed(admin);
        res.oracle = deployOracle(admin, 0);

        res.oracle.submitPendingOracle(
            address(res.debt), IOracleV1Plus.Oracle(res.debtOracle, res.debtOracle, 0, 0, 365 days, 0)
        );
        res.oracle.submitPendingOracle(
            address(res.collateral), IOracleV1Plus.Oracle(res.collateralOracle, res.collateralOracle, 0, 0, 365 days, 0)
        );
        res.oracle.acceptPendingOracle(address(res.debt));
        res.oracle.acceptPendingOracle(address(res.collateral));

        MockPriceFeed.RoundData memory roundData = MockPriceFeed.RoundData({
            roundId: 1,
            answer: int256(1e1 ** res.collateralOracle.decimals()),
            startedAt: 0,
            updatedAt: 0,
            answeredInRound: 0
        });
        res.collateralOracle.updateRoundData(roundData);

        MarketInitialParams memory initialParams = MarketInitialParams({
            collateral: address(res.collateral),
            debtToken: res.debt,
            admin: admin,
            gtImplementation: address(0),
            marketConfig: marketConfig,
            loanConfig: LoanConfig({
                oracle: IOracle(address(res.oracle)),
                liquidationLtv: liquidationLtv,
                maxLtv: maxLtv,
                liquidatable: true
            }),
            gtInitalParams: abi.encode(type(uint256).max),
            tokenName: "DAI-ETH",
            tokenSymbol: "DAI-ETH"
        });

        res.marketConfig = marketConfig;
        res.market = ITermMaxMarket(res.factory.createMarket(GT_ERC20, initialParams, 0));

        (res.ft, res.xt, res.gt,,) = res.market.tokens();
    }

    function deployMockMarket(address admin, MarketConfig memory marketConfig, uint32 maxLtv, uint32 liquidationLtv)
        internal
        returns (Res memory res)
    {
        res.factory = deployFactoryWithMockOrder(admin);

        res.collateral = new MockERC20("ETH", "ETH", 18);
        res.debt = new MockERC20("DAI", "DAI", 8);

        res.debtOracle = new MockPriceFeed(admin);
        res.collateralOracle = new MockPriceFeed(admin);
        res.oracle = deployOracle(admin, 0);

        res.oracle.submitPendingOracle(
            address(res.debt), IOracleV1Plus.Oracle(res.debtOracle, res.debtOracle, 0, 0, 365 days, 0)
        );
        res.oracle.submitPendingOracle(
            address(res.collateral), IOracleV1Plus.Oracle(res.collateralOracle, res.collateralOracle, 0, 0, 365 days, 0)
        );
        res.oracle.acceptPendingOracle(address(res.debt));
        res.oracle.acceptPendingOracle(address(res.collateral));

        MockPriceFeed.RoundData memory roundData = MockPriceFeed.RoundData({
            roundId: 1,
            answer: int256(1e1 ** res.collateralOracle.decimals()),
            startedAt: 0,
            updatedAt: 0,
            answeredInRound: 0
        });
        res.collateralOracle.updateRoundData(roundData);

        MarketInitialParams memory initialParams = MarketInitialParams({
            collateral: address(res.collateral),
            debtToken: res.debt,
            admin: admin,
            gtImplementation: address(0),
            marketConfig: marketConfig,
            loanConfig: LoanConfig({
                oracle: IOracle(address(res.oracle)),
                liquidationLtv: liquidationLtv,
                maxLtv: maxLtv,
                liquidatable: true
            }),
            gtInitalParams: abi.encode(type(uint256).max),
            tokenName: "DAI-ETH",
            tokenSymbol: "DAI-ETH"
        });

        res.marketConfig = marketConfig;
        res.market = ITermMaxMarket(res.factory.createMarket(GT_ERC20, initialParams, 0));

        (res.ft, res.xt, res.gt,,) = res.market.tokens();
    }

    function deployOrder(
        ITermMaxMarket market,
        address maker,
        uint256 maxXtReserve,
        ISwapCallback swapTrigger,
        CurveCuts memory curveCuts
    ) public returns (ITermMaxOrder order) {
        order = market.createOrder(maker, maxXtReserve, swapTrigger, curveCuts);
    }

    function deployFactory(address admin) public returns (TermMaxFactoryV1Plus factory) {
        address tokenImplementation = address(new MintableERC20V1Plus());
        address orderImplementation = address(new TermMaxOrderV1Plus());
        TermMaxMarketV1Plus m = new TermMaxMarketV1Plus(tokenImplementation, orderImplementation);
        factory = new TermMaxFactoryV1Plus(admin, address(m));
    }

    function deployFactoryWithMockOrder(address admin) public returns (TermMaxFactoryV1Plus factory) {
        address tokenImplementation = address(new MintableERC20V1Plus());
        address orderImplementation = address(new MockOrderV1Plus());
        TermMaxMarketV1Plus m = new TermMaxMarketV1Plus(tokenImplementation, orderImplementation);
        factory = new TermMaxFactoryV1Plus(admin, address(m));
    }

    function deployOracle(address admin, uint256 timeLock) public returns (OracleAggregatorV1Plus oracle) {
        oracle = new OracleAggregatorV1Plus(admin, timeLock);
    }

    function deployRouter(address admin) public returns (TermMaxRouterV1Plus router) {
        TermMaxRouterV1Plus implementation = new TermMaxRouterV1Plus();
        bytes memory data = abi.encodeCall(TermMaxRouterV1Plus.initialize, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        router = TermMaxRouterV1Plus(address(proxy));
    }

    function deployVault(VaultInitialParamsV1Plus memory initialParams) public returns (ITermMaxVault vault) {
        OrderManagerV1Plus orderManager = new OrderManagerV1Plus();
        TermMaxVaultV1Plus implementation = new TermMaxVaultV1Plus(address(orderManager));
        TermMaxVaultFactoryV1Plus vaultFactory = new TermMaxVaultFactoryV1Plus(address(implementation));

        vault = ITermMaxVault(vaultFactory.createVault(initialParams, 0));
    }

    function deployAccessManager(address admin) internal returns (AccessManager accessManager) {
        AccessManager implementation = new AccessManager();
        bytes memory data = abi.encodeCall(AccessManager.initialize, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        accessManager = AccessManager(address(proxy));
    }
}
