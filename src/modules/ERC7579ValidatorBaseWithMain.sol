// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    UserOperation, _packValidationData as _packValidationData4337
} from "../external/ERC4337.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";

abstract contract ERC7579ValidatorBase is ERC7579ModuleBase {
    type ValidationData is uint256;

    ValidationData internal constant VALIDATION_FAILED = ValidationData.wrap(0);
    bytes4 internal constant EIP1271_SUCCESS = 0x1626ba7e;
    bytes4 internal constant EIP1271_FAILED = 0xFFFFFFFF;

    address public immutable MAIN_VALIDATOR;

    /**
     * If this Validator can be used as a "subvalidator", by a Main Validator / Validation
     * MultiPlexer / Validation, make sure to set MAIN_VALIDATOR to the address of the Main
     * Validator.
     * @param mainValidator - The address of the Main Validator, or zero if this Validator is not a
     * subvalidator.
     */
    constructor(address mainValidator) {
        MAIN_VALIDATOR = mainValidator;
    }

    modifier onlyMainValidator() {
        require(msg.sender == MAIN_VALIDATOR, "NOT_MAIN_VALIDATOR");
        _;
    }

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
        UserOperation calldata userOp,
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
