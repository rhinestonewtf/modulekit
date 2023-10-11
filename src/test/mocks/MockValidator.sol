// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "../../common/erc4337/UserOperation.sol";
import "../../common/IERC1271.sol";
import { IValidator, VALIDATION_SUCCESS } from "../../modulekit/IValidator.sol";

contract MockValidator is IValidator {
    /**
     * @dev validates userOperation
     * @param userOp User Operation to be validated.
     * @param userOpHash Hash of the User Operation to be validated.
     * @return sigValidationResult 0 if signature is valid, SIG_VALIDATION_FAILED otherwise.
     */
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        virtual
        returns (uint256)
    {
        return VALIDATION_SUCCESS;
    }

    function isValidSignature(
        bytes32 signedDataHash,
        bytes memory moduleSignature
    )
        public
        view
        virtual
        returns (bytes4)
    {
        return ERC1271_MAGICVALUE;
    }

    function recoverValidator(
        address recoveryModule,
        bytes calldata recoveryProof,
        bytes calldata recoveryData
    )
        external
        virtual
    {
        return;
    }

    function supportsInterface(bytes4 interfaceID) external view override returns (bool) { }
}
