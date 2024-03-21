// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    PackedUserOperation,
    _packValidationData as _packValidationData4337
} from "../external/ERC4337.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";

abstract contract ERC7579ValidatorBase is ERC7579ModuleBase {
    type ValidationData is uint256;

    ValidationData internal constant VALIDATION_SUCCESS = ValidationData.wrap(0);
    ValidationData internal constant VALIDATION_FAILED = ValidationData.wrap(1);
    bytes4 internal constant EIP1271_SUCCESS = 0x1626ba7e;
    bytes4 internal constant EIP1271_FAILED = 0xFFFFFFFF;

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

    function _unpackValidationData(ValidationData _packedData)
        internal
        pure
        returns (bool sigFailed, uint48 validUntil, uint48 validAfter)
    {
        uint256 packedData = ValidationData.unwrap(_packedData);
        sigFailed = (packedData & 1) == 1;
        validUntil = uint48((packedData >> 160) & ((1 << 48) - 1));
        validAfter = uint48((packedData >> (160 + 48)) & ((1 << 48) - 1));
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
