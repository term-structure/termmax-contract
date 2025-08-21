// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../v1/router/MarketViewer.sol";
import {VersionV1Plus} from "../VersionV1Plus.sol";

contract MarketViewerV1Plus is MarketViewer, VersionV1Plus {
    function assetsWithERC20Collateral(ITermMaxMarket market, address owner)
        external
        view
        virtual
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
}
