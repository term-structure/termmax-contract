// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ITermMaxMarket} from "../../v1/ITermMaxMarket.sol";
import {ITermMaxMarketV1Plus} from "../ITermMaxMarketV1Plus.sol";
import {ITermMaxOrder} from "../../v1/ITermMaxOrder.sol";
import {SwapUnit} from "../../v1/router/ISwapAdapter.sol";
import {RouterErrors} from "../../v1/errors/RouterErrors.sol";
import {RouterEvents} from "../../v1/events/RouterEvents.sol";
import {IFlashLoanReceiver} from "../../v1/IFlashLoanReceiver.sol";
import {IFlashRepayer} from "../../v1/tokens/IFlashRepayer.sol";
import {ITermMaxRouterV1Plus} from "./ITermMaxRouterV1Plus.sol";
import {IGearingToken} from "../../v1/tokens/IGearingToken.sol";
import {IGearingTokenV1Plus} from "../tokens/IGearingTokenV1Plus.sol";
import {CurveCuts, OrderConfig} from "../../v1/storage/TermMaxStorage.sol";
import {Constants} from "../../v1/lib/Constants.sol";
import {IERC20SwapAdapter} from "./IERC20SwapAdapter.sol";
import {RouterEventsV1Plus} from "../events/RouterEventsV1Plus.sol";
import {RouterErrorsV1Plus} from "../errors/RouterErrorsV1Plus.sol";
import {TransferUtilsV1Plus} from "../lib/TransferUtilsV1Plus.sol";
import {ArrayUtilsV1Plus} from "../lib/ArrayUtilsV1Plus.sol";

/**
 * @title TermMax Router V1Plus
 * @author Term Structure Labs
 */
contract TermMaxRouterV1Plus is
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    IFlashLoanReceiver,
    IFlashRepayer,
    IERC721Receiver,
    ITermMaxRouterV1Plus,
    RouterErrors,
    RouterEvents
{
    using SafeCast for *;
    using TransferUtilsV1Plus for IERC20;
    using Math for *;
    using ArrayUtilsV1Plus for *;

    enum FlashLoanType {
        COLLATERAL,
        DEBT
    }

    enum FlashRepayOptions {
        REPAY,
        ROLLOVER
    }

    /// @notice whitelist mapping of adapter
    mapping(address => bool) public adapterWhitelist;

    uint256 private constant T_ROLLOVER_GT_RESERVE_STORE = 0;
    uint256 private constant T_CALLBACK_ADDRESS_STORE = 1;

    modifier onlyCallbackAddress() {
        address callbackAddress;
        assembly {
            callbackAddress := tload(T_CALLBACK_ADDRESS_STORE)
        }
        if (msg.sender != callbackAddress) {
            revert RouterErrorsV1Plus.CallbackAddressNotMatch();
        }
        _;
        assembly {
            // clear callback address after use
            tstore(T_CALLBACK_ADDRESS_STORE, 0)
        }
    }

    modifier noCallbackReentrant() {
        address callbackAddress;
        assembly {
            callbackAddress := tload(T_CALLBACK_ADDRESS_STORE)
        }
        if (callbackAddress != address(0)) {
            revert RouterErrorsV1Plus.CallbackReentrant();
        }
        _;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    function initialize(address admin) public initializer {
        __UUPSUpgradeable_init_unchained();
        __Pausable_init_unchained();
        __Ownable_init_unchained(admin);
    }

    function setAdapterWhitelist(address adapter, bool isWhitelist) external onlyOwner {
        adapterWhitelist[adapter] = isWhitelist;
        emit UpdateSwapAdapterWhiteList(adapter, isWhitelist);
    }

    function assetsWithERC20Collateral(ITermMaxMarket market, address owner)
        external
        view
        returns (IERC20[4] memory tokens, uint256[4] memory balances, address gtAddr, uint256[] memory gtIds)
    {
        (IERC20 ft, IERC20 xt, IGearingToken gt, address collateral, IERC20 underlying) = market.tokens();
        tokens[0] = ft;
        tokens[1] = xt;
        tokens[2] = IERC20(collateral);
        tokens[3] = underlying;
        for (uint256 i = 0; i < 4; ++i) {
            balances[i] = tokens[i].balanceOf(owner);
        }
        gtAddr = address(gt);
        uint256 balance = IERC721Enumerable(gtAddr).balanceOf(owner);
        gtIds = new uint256[](balance);
        for (uint256 i = 0; i < balance; ++i) {
            gtIds[i] = IERC721Enumerable(gtAddr).tokenOfOwnerByIndex(owner, i);
        }
    }

    function swapExactTokenToToken(
        IERC20 tokenIn,
        IERC20 tokenOut,
        address recipient,
        ITermMaxOrder[] memory orders,
        uint128[] memory tradingAmts,
        uint128 minTokenOut,
        uint256 deadline
    ) external whenNotPaused returns (uint256 netTokenOut) {
        uint256 totalAmtIn = tradingAmts.sum();
        tokenIn.safeTransferFrom(msg.sender, address(this), totalAmtIn);
        netTokenOut = _swapExactTokenToToken(tokenIn, tokenOut, recipient, orders, tradingAmts, minTokenOut, deadline);
        emit SwapExactTokenToToken(tokenIn, tokenOut, msg.sender, recipient, orders, tradingAmts, netTokenOut);
    }

    function _swapExactTokenToToken(
        IERC20 tokenIn,
        IERC20 tokenOut,
        address recipient,
        ITermMaxOrder[] memory orders,
        uint128[] memory tradingAmts,
        uint128 minTokenOut,
        uint256 deadline
    ) internal returns (uint256 netTokenOut) {
        if (orders.length != tradingAmts.length) revert OrdersAndAmtsLengthNotMatch();
        for (uint256 i = 0; i < orders.length; ++i) {
            ITermMaxOrder order = orders[i];
            tokenIn.safeIncreaseAllowance(address(order), tradingAmts[i]);
            netTokenOut += order.swapExactTokenToToken(tokenIn, tokenOut, recipient, tradingAmts[i], 0, deadline);
        }
        if (netTokenOut < minTokenOut) revert InsufficientTokenOut(address(tokenOut), netTokenOut, minTokenOut);
    }

    function swapTokenToExactToken(
        IERC20 tokenIn,
        IERC20 tokenOut,
        address recipient,
        ITermMaxOrder[] memory orders,
        uint128[] memory tradingAmts,
        uint128 maxTokenIn,
        uint256 deadline
    ) external whenNotPaused returns (uint256 netTokenIn) {
        tokenIn.safeTransferFrom(msg.sender, address(this), maxTokenIn);
        netTokenIn = _swapTokenToExactToken(tokenIn, tokenOut, recipient, orders, tradingAmts, maxTokenIn, deadline);
        tokenIn.safeTransfer(msg.sender, maxTokenIn - netTokenIn);
        emit SwapTokenToExactToken(tokenIn, tokenOut, msg.sender, recipient, orders, tradingAmts, netTokenIn);
    }

    function _swapTokenToExactToken(
        IERC20 tokenIn,
        IERC20 tokenOut,
        address recipient,
        ITermMaxOrder[] memory orders,
        uint128[] memory tradingAmts,
        uint128 maxTokenIn,
        uint256 deadline
    ) internal returns (uint256 netTokenIn) {
        if (orders.length != tradingAmts.length) revert OrdersAndAmtsLengthNotMatch();
        for (uint256 i = 0; i < orders.length; ++i) {
            ITermMaxOrder order = orders[i];
            tokenIn.forceApprove(address(order), maxTokenIn);
            netTokenIn +=
                order.swapTokenToExactToken(tokenIn, tokenOut, recipient, tradingAmts[i], maxTokenIn, deadline);
        }
        if (netTokenIn > maxTokenIn) revert InsufficientTokenIn(address(tokenIn), netTokenIn, maxTokenIn);
    }

    function sellTokens(
        address recipient,
        ITermMaxMarket market,
        uint128 ftInAmt,
        uint128 xtInAmt,
        ITermMaxOrder[] memory orders,
        uint128[] memory amtsToSellTokens,
        uint128 minTokenOut,
        uint256 deadline
    ) external whenNotPaused returns (uint256 netTokenOut) {
        (IERC20 ft, IERC20 xt,,, IERC20 debtToken) = market.tokens();
        (uint256 maxBurn, IERC20 toenToSell) = ftInAmt > xtInAmt ? (xtInAmt, ft) : (ftInAmt, xt);
        ft.safeTransferFrom(msg.sender, address(this), ftInAmt);
        xt.safeTransferFrom(msg.sender, address(this), xtInAmt);
        ft.safeIncreaseAllowance(address(market), ftInAmt);
        xt.safeIncreaseAllowance(address(market), xtInAmt);
        market.burn(recipient, maxBurn);

        netTokenOut = _swapExactTokenToToken(toenToSell, debtToken, recipient, orders, amtsToSellTokens, 0, deadline);
        netTokenOut += maxBurn;
        if (netTokenOut < minTokenOut) revert InsufficientTokenOut(address(debtToken), netTokenOut, minTokenOut);
        emit SellTokens(market, msg.sender, recipient, ftInAmt, xtInAmt, orders, amtsToSellTokens, netTokenOut);
    }

    function leverageFromToken(
        address recipient,
        ITermMaxMarket market,
        ITermMaxOrder[] memory orders,
        uint128[] memory amtsToBuyXt,
        uint128 minXtOut,
        uint128 tokenToSwap,
        uint128 maxLtv,
        SwapUnit[] memory units,
        uint256 deadline
    ) external whenNotPaused noCallbackReentrant returns (uint256 gtId, uint256 netXtOut) {
        assembly {
            tstore(T_CALLBACK_ADDRESS_STORE, market) // set callback address
        }
        (, IERC20 xt, IGearingToken gt,, IERC20 debtToken) = market.tokens();
        uint256 totalAmtToBuyXt = amtsToBuyXt.sum();
        debtToken.safeTransferFrom(msg.sender, address(this), tokenToSwap + totalAmtToBuyXt);
        netXtOut = _swapExactTokenToToken(debtToken, xt, address(this), orders, amtsToBuyXt, minXtOut, deadline);
        xt.safeIncreaseAllowance(address(market), netXtOut);
        bytes memory callbackData = abi.encode(address(gt), tokenToSwap, units, FlashLoanType.DEBT);
        gtId = market.leverageByXt(recipient, netXtOut.toUint128(), callbackData);
        (,, bytes memory collateralData) = gt.loanInfo(gtId);
        (, uint128 ltv,) = gt.getLiquidationInfo(gtId);
        if (ltv > maxLtv) {
            revert LtvBiggerThanExpected(maxLtv, ltv);
        }
        emit IssueGt(market, gtId, msg.sender, recipient, tokenToSwap, netXtOut.toUint128(), ltv, collateralData);
    }

    function leverageFromXt(
        address recipient,
        ITermMaxMarket market,
        uint128 xtInAmt,
        uint128 tokenInAmt,
        uint128 maxLtv,
        SwapUnit[] memory units
    ) external whenNotPaused noCallbackReentrant returns (uint256 gtId) {
        assembly {
            tstore(T_CALLBACK_ADDRESS_STORE, market) // set callback address
        }
        (, IERC20 xt, IGearingToken gt,, IERC20 debtToken) = market.tokens();
        debtToken.safeTransferFrom(msg.sender, address(this), tokenInAmt);
        xt.safeTransferFrom(msg.sender, address(this), xtInAmt);
        xt.safeIncreaseAllowance(address(market), xtInAmt);

        bytes memory callbackData = abi.encode(address(gt), tokenInAmt, units, FlashLoanType.DEBT);
        gtId = market.leverageByXt(recipient, xtInAmt.toUint128(), callbackData);

        (,, bytes memory collateralData) = gt.loanInfo(gtId);
        (, uint128 ltv,) = gt.getLiquidationInfo(gtId);
        if (ltv > maxLtv) {
            revert LtvBiggerThanExpected(maxLtv, ltv);
        }
        emit IssueGt(market, gtId, msg.sender, recipient, tokenInAmt, xtInAmt, ltv, collateralData);
    }

    function leverageFromXtAndCollateral(
        address recipient,
        ITermMaxMarket market,
        uint128 xtInAmt,
        uint128 collateralInAmt,
        uint128 maxLtv,
        SwapUnit[] memory units
    ) external whenNotPaused noCallbackReentrant returns (uint256 gtId) {
        assembly {
            tstore(T_CALLBACK_ADDRESS_STORE, market) // set callback address
        }
        (, IERC20 xt, IGearingToken gt, address collAddr,) = market.tokens();
        IERC20 collateral = IERC20(collAddr);

        collateral.safeTransferFrom(msg.sender, address(this), collateralInAmt);
        collateral.safeIncreaseAllowance(address(market), collateralInAmt);

        xt.safeTransferFrom(msg.sender, address(this), xtInAmt);
        xt.safeIncreaseAllowance(address(market), xtInAmt);

        bytes memory callbackData = abi.encode(address(gt), 0, units, FlashLoanType.COLLATERAL);
        gtId = market.leverageByXt(recipient, xtInAmt.toUint128(), callbackData);

        (,, bytes memory collateralData) = gt.loanInfo(gtId);
        (, uint128 ltv,) = gt.getLiquidationInfo(gtId);
        if (ltv > maxLtv) {
            revert LtvBiggerThanExpected(maxLtv, ltv);
        }
        emit IssueGt(market, gtId, msg.sender, recipient, 0, xtInAmt, ltv, collateralData);
    }

    function borrowTokenFromCollateral(
        address recipient,
        ITermMaxMarket market,
        uint256 collInAmt,
        ITermMaxOrder[] memory orders,
        uint128[] memory tokenAmtsWantBuy,
        uint128 maxDebtAmt,
        uint256 deadline
    ) external whenNotPaused returns (uint256) {
        (IERC20 ft,, IGearingToken gt, address collateralAddr, IERC20 debtToken) = market.tokens();
        IERC20(collateralAddr).safeTransferFrom(msg.sender, address(this), collInAmt);
        IERC20(collateralAddr).safeIncreaseAllowance(address(gt), collInAmt);

        (uint256 gtId, uint128 ftOutAmt) = market.issueFt(address(this), maxDebtAmt, _encodeAmount(collInAmt));
        uint256 netTokenIn =
            _swapTokenToExactToken(ft, debtToken, recipient, orders, tokenAmtsWantBuy, ftOutAmt, deadline);
        uint256 repayAmt = ftOutAmt - netTokenIn;
        if (repayAmt > 0) {
            ft.safeIncreaseAllowance(address(gt), repayAmt);
            // repay in ft, bool false means not using debt token
            gt.repay(gtId, repayAmt.toUint128(), false);
        }

        gt.safeTransferFrom(address(this), recipient, gtId);
        emit Borrow(market, gtId, msg.sender, recipient, collInAmt, ftOutAmt, netTokenIn.toUint128());
        return gtId;
    }

    function borrowTokenFromCollateral(address recipient, ITermMaxMarket market, uint256 collInAmt, uint256 borrowAmt)
        external
        whenNotPaused
        returns (uint256)
    {
        (IERC20 ft, IERC20 xt, IGearingToken gt, address collateralAddr,) = market.tokens();

        IERC20(collateralAddr).safeTransferFrom(msg.sender, address(this), collInAmt);
        IERC20(collateralAddr).safeIncreaseAllowance(address(gt), collInAmt);

        uint256 mintGtFeeRatio = market.mintGtFeeRatio();
        uint128 debtAmt = ((borrowAmt * Constants.DECIMAL_BASE) / (Constants.DECIMAL_BASE - mintGtFeeRatio)).toUint128();

        (uint256 gtId, uint128 ftOutAmt) = market.issueFt(address(this), debtAmt, _encodeAmount(collInAmt));
        borrowAmt = borrowAmt.min(ftOutAmt);
        xt.safeTransferFrom(msg.sender, address(this), borrowAmt);
        ft.safeIncreaseAllowance(address(market), borrowAmt);
        xt.safeIncreaseAllowance(address(market), borrowAmt);
        market.burn(recipient, borrowAmt);

        gt.safeTransferFrom(address(this), recipient, gtId);
        emit Borrow(market, gtId, msg.sender, recipient, collInAmt, debtAmt, borrowAmt.toUint128());
        return gtId;
    }

    function borrowTokenFromGt(address recipient, ITermMaxMarket market, uint256 gtId, uint256 borrowAmt)
        external
        whenNotPaused
    {
        (IERC20 ft, IERC20 xt, IGearingToken gt,,) = market.tokens();

        if (gt.ownerOf(gtId) != msg.sender) {
            revert GtNotOwnedBySender();
        }

        uint256 mintGtFeeRatio = market.mintGtFeeRatio();
        uint128 debtAmt = ((borrowAmt * Constants.DECIMAL_BASE) / (Constants.DECIMAL_BASE - mintGtFeeRatio)).toUint128();

        uint256 ftOutAmt = market.issueFtByExistedGt(address(this), debtAmt, gtId);
        borrowAmt = borrowAmt.min(ftOutAmt);
        xt.safeTransferFrom(msg.sender, address(this), borrowAmt);
        ft.safeIncreaseAllowance(address(market), borrowAmt);
        xt.safeIncreaseAllowance(address(market), borrowAmt);
        market.burn(recipient, borrowAmt);

        emit Borrow(market, gtId, msg.sender, recipient, 0, debtAmt, borrowAmt.toUint128());
    }

    /**
     *  Deprecated function
     *  @dev use `flashRepayFromCollV1Plus` instead
     */
    function flashRepayFromColl(
        address recipient,
        ITermMaxMarket market,
        uint256 gtId,
        bool byDebtToken,
        uint256 expectedOutput,
        SwapUnit[] memory units,
        TermMaxSwapData memory swapData
    ) external whenNotPaused noCallbackReentrant returns (uint256 netTokenOut) {
        (,, IGearingToken gtToken,, IERC20 debtToken) = market.tokens();
        assembly {
            tstore(T_CALLBACK_ADDRESS_STORE, gtToken) // set callback address
        }
        gtToken.safeTransferFrom(msg.sender, address(this), gtId, "");
        bytes memory callbackData = abi.encode(units, swapData);
        callbackData = abi.encode(FlashRepayOptions.REPAY, callbackData);
        gtToken.flashRepay(gtId, byDebtToken, callbackData);
        netTokenOut = debtToken.balanceOf(address(this));
        if (netTokenOut < expectedOutput) {
            revert InsufficientTokenOut(address(debtToken), expectedOutput, netTokenOut);
        }
        debtToken.safeTransfer(recipient, netTokenOut);
    }

    function flashRepayFromCollV1Plus(
        address recipient,
        ITermMaxMarket market,
        uint256 gtId,
        uint128 repayAmt,
        bool byDebtToken,
        uint256 expectedOutput,
        bytes memory removedCollateral,
        SwapUnit[] memory units,
        TermMaxSwapData memory swapData
    ) external whenNotPaused noCallbackReentrant returns (uint256 netTokenOut) {
        (,, IGearingToken gtToken,, IERC20 debtToken) = market.tokens();
        assembly {
            tstore(T_CALLBACK_ADDRESS_STORE, gtToken) // set callback address
        }
        gtToken.safeTransferFrom(msg.sender, address(this), gtId, "");
        bytes memory callbackData = abi.encode(units, swapData);
        callbackData = abi.encode(FlashRepayOptions.REPAY, callbackData);
        bool repayAll = IGearingTokenV1Plus(address(gtToken)).flashRepay(
            gtId, repayAmt, byDebtToken, removedCollateral, callbackData
        );
        if (!repayAll) {
            gtToken.safeTransferFrom(address(this), msg.sender, gtId);
        }
        netTokenOut = debtToken.balanceOf(address(this));
        if (netTokenOut < expectedOutput) {
            revert InsufficientTokenOut(address(debtToken), expectedOutput, netTokenOut);
        }
        debtToken.safeTransfer(recipient, netTokenOut);
    }

    function repayByTokenThroughFt(
        address recipient,
        ITermMaxMarket market,
        uint256 gtId,
        ITermMaxOrder[] memory orders,
        uint128[] memory ftAmtsWantBuy,
        uint128 maxTokenIn,
        uint256 deadline
    ) external whenNotPaused returns (uint256 returnAmt) {
        (IERC20 ft,, IGearingToken gt,, IERC20 debtToken) = market.tokens();

        debtToken.safeTransferFrom(msg.sender, address(this), maxTokenIn);
        uint256 netCost =
            _swapTokenToExactToken(debtToken, ft, address(this), orders, ftAmtsWantBuy, maxTokenIn, deadline);
        uint256 totalFtAmt = ftAmtsWantBuy.sum();
        (, uint128 repayAmt,) = gt.loanInfo(gtId);

        if (totalFtAmt < repayAmt) {
            repayAmt = totalFtAmt.toUint128();
        }
        ft.safeIncreaseAllowance(address(gt), repayAmt);
        // repay in ft, bool false means not using debt token
        gt.repay(gtId, repayAmt, false);

        returnAmt = maxTokenIn - netCost;
        debtToken.safeTransfer(recipient, returnAmt);
        if (totalFtAmt > repayAmt) {
            ft.safeTransfer(recipient, totalFtAmt - repayAmt);
        }

        emit RepayByTokenThroughFt(market, gtId, msg.sender, recipient, repayAmt, returnAmt);
    }

    /**
     * @inheritdoc ITermMaxRouterV1Plus
     */
    function repayGt(ITermMaxMarket market, uint256 gtId, uint128 maxRepayAmt, bool byDebtToken)
        external
        override
        whenNotPaused
        returns (uint128 repayAmt)
    {
        (IERC20 ft,, IGearingToken gt,, IERC20 debtToken) = market.tokens();
        (, uint128 debtAmt,) = gt.loanInfo(gtId); // Ensure gtId is valid
        if (maxRepayAmt > debtAmt) {
            repayAmt = debtAmt;
        } else {
            repayAmt = maxRepayAmt;
        }
        IERC20 repayToken = byDebtToken ? debtToken : ft;
        repayToken.safeTransferFrom(msg.sender, address(this), repayAmt);
        repayToken.safeIncreaseAllowance(address(gt), repayAmt);
        gt.repay(gtId, repayAmt, byDebtToken);
    }

    function redeemAndSwap(
        address recipient,
        ITermMaxMarket market,
        uint256 ftAmount,
        SwapUnit[] memory units,
        uint256 minTokenOut
    ) external whenNotPaused returns (uint256) {
        (IERC20 ft,,,, IERC20 debtToken) = market.tokens();
        ft.safeTransferFrom(msg.sender, address(this), ftAmount);
        ft.safeIncreaseAllowance(address(market), ftAmount);
        (uint256 redeemedAmt, bytes memory collateralData) = market.redeem(ftAmount, address(this));
        redeemedAmt += _doSwap(_decodeAmount(collateralData), units);
        if (redeemedAmt < minTokenOut) {
            revert InsufficientTokenOut(address(debtToken), redeemedAmt, minTokenOut);
        }
        debtToken.safeTransfer(recipient, redeemedAmt);
        emit RedeemAndSwap(market, ftAmount, msg.sender, recipient, redeemedAmt);
        return redeemedAmt;
    }

    /**
     * @inheritdoc ITermMaxRouterV1Plus
     */
    function placeOrderForV1(
        ITermMaxMarket market,
        address maker,
        uint256 collateralToMintGt,
        uint256 debtTokenToDeposit,
        uint128 ftToDeposit,
        uint128 xtToDeposit,
        OrderConfig memory orderConfig
    ) external whenNotPaused returns (ITermMaxOrder order, uint256 gtId) {
        (IERC20 ft, IERC20 xt, IGearingToken gt, address collateral, IERC20 debtToken) = market.tokens();
        if (collateralToMintGt > 0) {
            IERC20(collateral).safeTransferFrom(msg.sender, address(this), collateralToMintGt);
            IERC20(collateral).safeIncreaseAllowance(address(gt), collateralToMintGt);
            (gtId,) = market.issueFt(maker, 0, _encodeAmount(collateralToMintGt));
        }
        order = market.createOrder(maker, orderConfig.maxXtReserve, orderConfig.swapTrigger, orderConfig.curveCuts);

        if (debtTokenToDeposit > 0) {
            debtToken.safeTransferFrom(msg.sender, address(this), debtTokenToDeposit);
            debtToken.safeIncreaseAllowance(address(market), debtTokenToDeposit);
            market.mint(address(order), debtTokenToDeposit);
        }
        ft.safeTransferFrom(msg.sender, address(order), ftToDeposit);
        xt.safeTransferFrom(msg.sender, address(order), xtToDeposit);
        emit RouterEventsV1Plus.PlaceOrder(maker, address(order), address(market), gtId, orderConfig);
    }

    /**
     * @inheritdoc ITermMaxRouterV1Plus
     */
    function placeOrderForV1Plus(
        ITermMaxMarket market,
        address maker,
        uint256 collateralToMintGt,
        uint256 debtTokenToDeposit,
        uint128 ftToDeposit,
        uint128 xtToDeposit,
        OrderConfig memory orderConfig
    ) external whenNotPaused returns (ITermMaxOrder order, uint256 gtId) {
        (IERC20 ft, IERC20 xt, IGearingToken gt, address collateral, IERC20 debtToken) = market.tokens();
        if (collateralToMintGt > 0) {
            IERC20(collateral).safeTransferFrom(msg.sender, address(this), collateralToMintGt);
            IERC20(collateral).safeIncreaseAllowance(address(gt), collateralToMintGt);
            (orderConfig.gtId,) = market.issueFt(maker, 0, _encodeAmount(collateralToMintGt));
        }
        order = ITermMaxMarketV1Plus(address(market)).createOrder(maker, orderConfig);

        if (debtTokenToDeposit > 0) {
            debtToken.safeTransferFrom(msg.sender, address(this), debtTokenToDeposit);
            debtToken.safeIncreaseAllowance(address(market), debtTokenToDeposit);
            market.mint(address(order), debtTokenToDeposit);
        }
        ft.safeTransferFrom(msg.sender, address(order), ftToDeposit);
        xt.safeTransferFrom(msg.sender, address(order), xtToDeposit);
        emit RouterEventsV1Plus.PlaceOrder(maker, address(order), address(market), gtId, orderConfig);
    }

    /**
     * @inheritdoc ITermMaxRouterV1Plus
     */
    function rolloverGt(
        address recipient,
        IGearingToken gtToken,
        uint256 gtId,
        uint128 additionalAssets,
        SwapUnit[] memory units,
        ITermMaxMarket nextMarket,
        uint256 additionalNextCollateral,
        TermMaxSwapData memory swapData,
        uint128 maxLtv
    ) external whenNotPaused noCallbackReentrant returns (uint256 newGtId) {
        assembly {
            // set callback address
            tstore(T_CALLBACK_ADDRESS_STORE, gtToken)
            // clear ts stograge
            tstore(T_ROLLOVER_GT_RESERVE_STORE, 0)
        }
        // additional debt token to reduce the ltv
        if (additionalAssets != 0) {
            IERC20(swapData.tokenOut).safeTransferFrom(msg.sender, address(this), additionalAssets);
        }
        // additional collateral to reduce the ltv
        if (additionalNextCollateral != 0) {
            IERC20(units[units.length - 1].tokenOut).safeTransferFrom(
                msg.sender, address(this), additionalNextCollateral
            );
        }
        gtToken.safeTransferFrom(msg.sender, address(this), gtId, "");
        bytes memory callbackData =
            abi.encode(recipient, maxLtv, additionalAssets, nextMarket, additionalNextCollateral, units, swapData);
        callbackData = abi.encode(FlashRepayOptions.ROLLOVER, callbackData);
        gtToken.flashRepay(gtId, true, callbackData);
        assembly {
            newGtId := tload(T_ROLLOVER_GT_RESERVE_STORE)
        }
    }

    /**
     * @inheritdoc ITermMaxRouterV1Plus
     */
    function rolloverGtV1Plus(
        address recipient,
        IGearingToken gtToken,
        uint256 gtId,
        uint128 repayAmt,
        uint128 additionalAssets,
        uint256 removedCollateral,
        SwapUnit[] memory units,
        ITermMaxMarket nextMarket,
        uint256 additionalNextCollateral,
        TermMaxSwapData memory swapData,
        uint128 maxLtv
    ) external whenNotPaused noCallbackReentrant returns (uint256 newGtId) {
        assembly {
            // set callback address
            tstore(T_CALLBACK_ADDRESS_STORE, gtToken)
            // clear ts stograge
            tstore(T_ROLLOVER_GT_RESERVE_STORE, 0)
        }
        // additional debt token to reduce the ltv
        if (additionalAssets != 0) {
            IERC20(swapData.tokenOut).safeTransferFrom(msg.sender, address(this), additionalAssets);
        }
        // additional collateral to reduce the ltv
        if (additionalNextCollateral != 0) {
            IERC20(units[units.length - 1].tokenOut).safeTransferFrom(
                msg.sender, address(this), additionalNextCollateral
            );
        }
        gtToken.safeTransferFrom(msg.sender, address(this), gtId, "");
        bytes memory callbackData =
            abi.encode(recipient, maxLtv, additionalAssets, nextMarket, additionalNextCollateral, units, swapData);
        callbackData = abi.encode(FlashRepayOptions.ROLLOVER, callbackData);
        if (
            !IGearingTokenV1Plus(address(gtToken)).flashRepay(
                gtId, repayAmt, true, abi.encode(removedCollateral), callbackData
            )
        ) {
            gtToken.safeTransferFrom(address(this), recipient, gtId);
        }
        assembly {
            newGtId := tload(T_ROLLOVER_GT_RESERVE_STORE)
        }
    }

    /// @dev Market flash leverage flashloan callback
    function executeOperation(address, IERC20, uint256 amount, bytes memory data)
        external
        override
        onlyCallbackAddress
        returns (bytes memory collateralData)
    {
        (address gt, uint256 tokenInAmt, SwapUnit[] memory units, FlashLoanType flashLoanType) =
            abi.decode(data, (address, uint256, SwapUnit[], FlashLoanType));
        uint256 totalAmount = amount + tokenInAmt;
        uint256 collateralBalance = _doSwap(totalAmount, units);
        SwapUnit memory lastUnit = units[units.length - 1];
        if (!adapterWhitelist[lastUnit.adapter]) {
            revert AdapterNotWhitelisted(lastUnit.adapter);
        }
        IERC20 collateral = IERC20(lastUnit.tokenOut);
        if (flashLoanType == FlashLoanType.COLLATERAL) {
            collateralBalance = collateral.balanceOf(address(this));
        }
        collateral.safeIncreaseAllowance(gt, collateralBalance);
        collateralData = _encodeAmount(collateralBalance);
    }

    function _balanceOf(IERC20 token, address account) internal view returns (uint256) {
        return token.balanceOf(account);
    }

    function _encodeAmount(uint256 amount) internal pure returns (bytes memory) {
        return abi.encode(amount);
    }

    function _decodeAmount(bytes memory collateralData) internal pure returns (uint256) {
        return abi.decode(collateralData, (uint256));
    }

    /// @dev Gt flash repay flashloan callback
    function executeOperation(
        IERC20 repayToken,
        uint128 debtAmt,
        address,
        bytes memory collateralData,
        bytes memory callbackData
    ) external override onlyCallbackAddress {
        (FlashRepayOptions option, bytes memory data) = abi.decode(callbackData, (FlashRepayOptions, bytes));
        if (option == FlashRepayOptions.REPAY) {
            _flashRepay(repayToken, collateralData, data);
        } else if (option == FlashRepayOptions.ROLLOVER) {
            _rollover(repayToken, debtAmt, collateralData, data);
        }
        repayToken.safeIncreaseAllowance(msg.sender, debtAmt);
    }

    function _flashRepay(IERC20, bytes memory collateralData, bytes memory callbackData) internal {
        (SwapUnit[] memory units, TermMaxSwapData memory swapData) =
            abi.decode(callbackData, (SwapUnit[], TermMaxSwapData));
        uint256 amount = _doSwap(_decodeAmount(collateralData), units);

        if (swapData.orders.length > 0) {
            // swap token to exact token
            _swapTokenToExactToken(
                IERC20(swapData.tokenIn),
                IERC20(swapData.tokenOut),
                address(this),
                swapData.orders,
                swapData.tradingAmts,
                amount.toUint128(),
                swapData.deadline
            );
        }
    }

    function _rollover(IERC20 debtToken, uint256 debtAmt, bytes memory collateralData, bytes memory callbackData)
        internal
    {
        (
            address recipient,
            uint128 maxLtv,
            uint128 additionalAssets,
            ITermMaxMarket market,
            uint256 additionalNextCollateral,
            SwapUnit[] memory units,
            TermMaxSwapData memory swapData
        ) = abi.decode(callbackData, (address, uint128, uint128, ITermMaxMarket, uint256, SwapUnit[], TermMaxSwapData));
        {
            // swap collateral
            collateralData =
                units.length == 0 ? collateralData : _encodeAmount(_doSwap(_decodeAmount(collateralData), units));
        }
        (IERC20 ft,, IGearingToken gt, address collateral,) = market.tokens();
        uint256 gtId;
        {
            // issue new gt
            uint256 mintGtFeeRatio = market.mintGtFeeRatio();
            uint128 newDebtAmt = (
                (swapData.netTokenAmt * Constants.DECIMAL_BASE) / (Constants.DECIMAL_BASE - mintGtFeeRatio)
            ).toUint128();
            uint256 newCollateralAmt = _decodeAmount(collateralData) + additionalNextCollateral;
            IERC20(collateral).safeIncreaseAllowance(address(gt), newCollateralAmt);
            (gtId,) = market.issueFt(address(this), newDebtAmt, abi.encode(newCollateralAmt));
        }
        {
            uint256 netFtIn = _swapTokenToExactToken(
                ft,
                debtToken,
                address(this),
                swapData.orders,
                swapData.tradingAmts,
                swapData.netTokenAmt,
                swapData.deadline
            );
            // check remaining ft amount
            if (swapData.netTokenAmt > netFtIn) {
                uint256 repaidFtAmt = swapData.netTokenAmt - netFtIn;
                ft.safeIncreaseAllowance(address(gt), repaidFtAmt);
                // repay in ft, bool false means not using debt token
                gt.repay(gtId, repaidFtAmt.toUint128(), false);
            }
            // check remaining debt token amount
            uint256 totalDebtTokenAmt = swapData.tradingAmts.sum() + additionalAssets;
            if (totalDebtTokenAmt > debtAmt) {
                uint256 repaidDebtAmt = totalDebtTokenAmt - debtAmt;
                debtToken.safeIncreaseAllowance(address(gt), repaidDebtAmt);
                // repay in debt token, bool true means using debt token
                gt.repay(gtId, repaidDebtAmt.toUint128(), true);
            }
            (, uint128 ltv,) = gt.getLiquidationInfo(gtId);
            if (ltv > maxLtv) {
                revert LtvBiggerThanExpected(maxLtv, ltv);
            }
        }
        // transfer new gt to recipient
        gt.safeTransferFrom(address(this), recipient, gtId);
        assembly {
            tstore(T_ROLLOVER_GT_RESERVE_STORE, gtId)
        }
    }

    function _doSwap(uint256 inputAmt, SwapUnit[] memory units) internal returns (uint256 outputAmt) {
        if (units.length == 0) {
            revert SwapUnitsIsEmpty();
        }
        for (uint256 i = 0; i < units.length; ++i) {
            if (!adapterWhitelist[units[i].adapter]) {
                revert AdapterNotWhitelisted(units[i].adapter);
            }
            bytes memory dataToSwap = abi.encodeCall(
                IERC20SwapAdapter.swap,
                (address(this), units[i].tokenIn, units[i].tokenOut, inputAmt, units[i].swapData)
            );

            (bool success, bytes memory returnData) = units[i].adapter.delegatecall(dataToSwap);
            if (!success) {
                revert SwapFailed(units[i].adapter, returnData);
            }
            inputAmt = abi.decode(returnData, (uint256));
        }
        outputAmt = inputAmt;
    }

    function onERC721Received(address, address, uint256, bytes memory) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
