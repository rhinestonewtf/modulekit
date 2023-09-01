// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import { UserOperation, BaseValidator } from "./BaseValidator.sol";

contract ValidatorTemplate is BaseValidator {
    /**
     * @dev validates userOperation
     * @param userOp User Operation to be validated.
     * @param userOpHash Hash of the User Operation to be validated.
     * @return sigValidationResult 0 if signature is valid, 1 otherwise.
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (uint256)
    {
        return VALIDATION_SUCCESS;
    }

    /**
     * @dev recovers the validator config if access is lost
     * @param recoveryModule Address of recovery module to validate proof.
     * @param recoveryProof Recovery proof validated by recovery module.
     * @param recoveryData Data to be recovered to.
     */
    function recoverValidator(
        address recoveryModule,
        bytes calldata recoveryProof,
        bytes calldata recoveryData
    )
        external
        override
    { }

    /**
     * @dev validates a 1271 signature request
     * @param signedDataHash Hash of the signed data.
     * @param moduleSignature Signature to be validated.
     * @return eip1271Result 0x1626ba7e if signature is valid, 0xffffffff otherwise.
     */
    function isValidSignature(
        bytes32 signedDataHash,
        bytes memory moduleSignature
    )
        public
        view
        override
        returns (bytes4)
    {
        return EIP1271_MAGIC_VALUE;
    }
}
