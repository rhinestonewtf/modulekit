// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import {UserOperation} from "@aa/interfaces/UserOperation.sol";
import {BaseValidator} from "../../src/modules/validators/BaseValidator.sol";

contract MockValidator is BaseValidator {
    /**
     * @dev validates userOperation
     * @param userOp User Operation to be validated.
     * @param userOpHash Hash of the User Operation to be validated.
     * @return sigValidationResult 0 if signature is valid, SIG_VALIDATION_FAILED otherwise.
     */
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash)
        external
        view
        virtual
        returns (uint256)
    {
        return VALIDATION_SUCCESS;
    }

    function isValidSignature(bytes32 signedDataHash, bytes memory moduleSignature)
        public
        view
        virtual
        override
        returns (bytes4)
    {
        return EIP1271_MAGIC_VALUE;
    }

    function recoverValidator(address recoveryModule, bytes calldata recoveryProof, bytes calldata recoveryData)
        external
        virtual
        override
    {
        return;
    }
}
