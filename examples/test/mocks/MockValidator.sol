// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    IValidator,
    PackedUserOperation,
    VALIDATION_SUCCESS,
    MODULE_TYPE_VALIDATOR
} from "erc7579/interfaces/IERC7579Module.sol";
import { IStatelessValidator } from "modulekit/src/interfaces/IStatelessValidator.sol";

contract MockValidator is IValidator, IStatelessValidator {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (uint256)
    {
        bytes4 execSelector = bytes4(userOp.callData[:4]);

        return VALIDATION_SUCCESS;
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        return 0x1626ba7e;
    }

    function validateSignatureWithData(
        bytes32 hash,
        bytes memory signature,
        bytes calldata data
    )
        external
        view
        returns (bool)
    {
        if (keccak256(signature) == keccak256(bytes("invalid"))) return false;
        return true;
    }

    function isModuleType(uint256 moduleTypeId) external view returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return false;
    }
}
