// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ITermMaxVaultV1Plus} from "../vault/ITermMaxVaultV1Plus.sol";
import {FactoryEventsV1Plus} from "../events/FactoryEventsV1Plus.sol";
import {ITermMaxVaultFactoryV1Plus} from "./ITermMaxVaultFactoryV1Plus.sol";
import {VaultInitialParamsV1Plus} from "../storage/TermMaxStorageV1Plus.sol";

/**
 * @title The TermMax vault factory V1Plus
 * @author Term Structure Labs
 */
contract TermMaxVaultFactoryV1Plus is ITermMaxVaultFactoryV1Plus {
    /**
     * @notice The implementation of TermMax Vault contract V1Plus
     */
    address public immutable TERMMAX_VAULT_IMPLEMENTATION;

    constructor(address TERMMAX_VAULT_IMPLEMENTATION_) {
        TERMMAX_VAULT_IMPLEMENTATION = TERMMAX_VAULT_IMPLEMENTATION_;
    }

    /**
     * @inheritdoc ITermMaxVaultFactoryV1Plus
     */
    function predictVaultAddress(
        address deployer,
        address asset,
        string memory name,
        string memory symbol,
        uint256 salt
    ) external view returns (address vault) {
        return Clones.predictDeterministicAddress(
            TERMMAX_VAULT_IMPLEMENTATION, keccak256(abi.encode(deployer, asset, name, symbol, salt))
        );
    }

    /**
     * @inheritdoc ITermMaxVaultFactoryV1Plus
     */
    function createVault(VaultInitialParamsV1Plus memory initialParams, uint256 salt) public returns (address vault) {
        vault = Clones.cloneDeterministic(
            TERMMAX_VAULT_IMPLEMENTATION,
            keccak256(abi.encode(msg.sender, initialParams.asset, initialParams.name, initialParams.symbol, salt))
        );
        ITermMaxVaultV1Plus(vault).initialize(initialParams);
        emit FactoryEventsV1Plus.VaultCreated(vault, msg.sender, initialParams);
    }
}
