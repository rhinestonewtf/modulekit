// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { PackedUserOperation } from "@rhinestone/modulekit/src/external/ERC4337.sol";

contract AutoSub is ERC7579ValidatorBase {
    mapping(address account => mapping(address module => bool autoSub)) internal _autosubs;

    function toggleAutoSub(address module) external {
        _autosubs[msg.sender][module] = !_autosubs[msg.sender][module];
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        virtual
        override
        returns (ValidationData)
    {
        return VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        if (sender != address(this)) return EIP1271_FAILED;

        // TODO: check hash
        (address module) = abi.decode(data, (address));
        if (_autosubs[msg.sender][module]) {
            return EIP1271_SUCCESS;
        }
    }

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) { }
}
