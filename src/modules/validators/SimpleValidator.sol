// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import {UserOperation, BaseValidator} from "./BaseValidator.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SimpleValidator is BaseValidator {
    using ECDSA for bytes32;

    mapping(address => address) public owners;

    function setOwner(address account, address owner) external {
        owners[account] = owner;
    }

    /**
     * @dev validates userOperation
     * @param userOp User Operation to be validated.
     * @param userOpHash Hash of the User Operation to be validated.
     * @return sigValidationResult 0 if signature is valid, 1 otherwise.
     */
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash)
        external
        view
        override
        returns (uint256)
    {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owners[msg.sender] != hash.recover(userOp.signature)) {
            return SIG_VALIDATION_FAILED;
        }
        return VALIDATION_SUCCESS;
    }

    /**
     * @dev recovers the validator config if access is lost
     * @param recoveryModule Address of recovery module to validate proof.
     * @param recoveryProof Recovery proof validated by recovery module.
     * @param recoveryData Data to be recovered to.
     */
    function recoverValidator(address recoveryModule, bytes calldata recoveryProof, bytes calldata recoveryData)
        external
        override
    {
        owners[msg.sender] = abi.decode(recoveryData, (address));
    }

    /**
     * @dev validates a 1271 signature request
     * @param signedDataHash Hash of the signed data.
     * @param moduleSignature Signature to be validated.
     * @return eip1271Result 0x1626ba7e if signature is valid, 0xffffffff otherwise.
     */
    function isValidSignature(bytes32 signedDataHash, bytes memory moduleSignature)
        public
        view
        override
        returns (bytes4)
    {
        bytes32 hash = signedDataHash.toEthSignedMessageHash();
        if (owners[msg.sender] != hash.recover(moduleSignature)) {
            return 0xffffffff;
        }
        return EIP1271_MAGIC_VALUE;
    }
}
