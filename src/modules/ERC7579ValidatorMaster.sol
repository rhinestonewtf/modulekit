// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    PackedUserOperation,
    _packValidationData as _packValidationData4337
} from "../external/ERC4337.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";

abstract contract ERC7579ValidatorBase is ERC7579ModuleBase {
    type ValidationData is uint256;

    ValidationData internal constant VALIDATION_FAILED = ValidationData.wrap(1);
    bytes4 internal constant EIP1271_SUCCESS = 0x1626ba7e;
    bytes4 internal constant EIP1271_FAILED = 0xFFFFFFFF;

    modifier notInitialized() virtual;
    modifier alreadyInitialized() virtual;

    // Modules may be intalled without being added to the account
    function onInstall(bytes calldata data) external virtual override notInitialized {
        _onInstall(data);
    }

    function onUninstall(bytes calldata data) external virtual override alreadyInitialized {
        _onUninstall(data);
    }

    function _onInstall(bytes calldata data) internal virtual;
    function _onUninstall(bytes calldata data) internal virtual;

    /**
     * Helper to pack the return value for validateUserOp, when not using an aggregator.
     * @param sigFailed  - True for signature failure, false for success.
     * @param validUntil - Last timestamp this UserOperation is valid (or zero for
     * infinite).
     * @param validAfter - First timestamp this UserOperation is valid.
     */
    function _packValidationData(
        bool sigFailed,
        uint48 validUntil,
        uint48 validAfter
    )
        internal
        pure
        returns (ValidationData)
    {
        return ValidationData.wrap(_packValidationData4337(sigFailed, validUntil, validAfter));
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        virtual
        returns (ValidationData);

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        returns (bytes4);
}
