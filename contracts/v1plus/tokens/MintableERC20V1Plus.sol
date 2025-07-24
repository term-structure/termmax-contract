// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IMintableERC20V1Plus} from "./IMintableERC20V1Plus.sol";
import {MintableERC20} from "../../v1/tokens/MintableERC20.sol";

/**
 * @title TermMax ERC20 token
 * @author Term Structure Labs
 */
contract MintableERC20V1Plus is MintableERC20, IMintableERC20V1Plus {
    /**
     * @inheritdoc IMintableERC20V1Plus
     */
    function burn(address owner, address spender, uint256 amount) external virtual override onlyOwner {
        if (owner != spender) {
            _spendAllowance(owner, spender, amount);
        }
        _burn(owner, amount);
    }
}
