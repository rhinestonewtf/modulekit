// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { LinkedBytes32Lib } from "sentinellist/SentinelListBytes32.sol";
import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";
import { ISubHook } from "../ISubHook.sol";
import { TokenTransactionLib } from "../lib/TokenTransactionLib.sol";
import "forge-std/console2.sol";

// bytes32 constant STORAGE_SLOT = keccak256("permissions.storage");
bytes32 constant STORAGE_SLOT = bytes32(uint256(123));

contract PermissionFlags is ISubHook {
    using SentinelListLib for SentinelListLib.SentinelList;
    using LinkedBytes32Lib for LinkedBytes32Lib.LinkedBytes32;
    using TokenTransactionLib for bytes4;

    error InvalidPermission();

    struct AccessFlags {
        // Execution permissions
        // - Target permissions
        bool selfCall;
        bool moduleCall;
        // - Value permissions
        bool sendValue;
        bool erc20Transfer;
        bool erc721Transfer;
        // - Calldata permissions
        bool hasAllowedFunctions;
        bool hasAllowedTargets;
        // Module configuration permissions
        bool moduleConfig;
    }

    struct ModulePermissions {
        AccessFlags flags;
        LinkedBytes32Lib.LinkedBytes32 allowedFunctions;
        SentinelListLib.SentinelList allowedTargets;
    }

    struct SubHookStorage {
        mapping(address account => mapping(address module => ModulePermissions)) permissions;
    }

    function $subHook() internal pure virtual returns (SubHookStorage storage shs) {
        bytes32 position = STORAGE_SLOT;
        assembly {
            shs.slot := position
        }
    }

    function configure(
        address module,
        AccessFlags calldata flags,
        address[] calldata allowedTargets,
        bytes4[] calldata allowedFunctions
    )
        external
    {
        ModulePermissions storage $modulePermissions = $subHook().permissions[msg.sender][module];
        $modulePermissions.flags = flags;

        uint256 length = allowedTargets.length;
        $modulePermissions.allowedTargets.init();
        for (uint256 i; i < length; i++) {
            $modulePermissions.allowedTargets.push(allowedTargets[i]);
        }
        length = allowedFunctions.length;
        for (uint256 i; i < length; i++) {
            $modulePermissions.allowedFunctions.push(bytes32(allowedFunctions[i]));
        }
    }

    function onExecute(
        address superVisorModule,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    {
        console2.log("onExecute subhook");
        ModulePermissions storage $modulePermissions =
            $subHook().permissions[msg.sender][superVisorModule];

        AccessFlags memory flags = $modulePermissions.flags;

        bytes4 functionSig = callData.length > 4 ? bytes4(callData[0:4]) : bytes4(0);

        // check for self call
        if (!flags.selfCall && target == msg.sender) {
            revert InvalidPermission();
        }

        // check for module Call
        // TODO:
        // if (!flags.moduleCall) {
        //     // if (!flags.moduleCall && IERC7579Module(target).moduleId(msg.sender)) {
        //     revert InvalidPermission();
        // }

        // check for value transfer
        if (!flags.sendValue && value > 0) {
            revert InvalidPermission();
        }

        // Calldata permissions
        if (flags.erc20Transfer && functionSig.isERC20Transfer()) {
            revert InvalidPermission();
        }

        if (flags.erc721Transfer && functionSig.isERC721Transfer()) {
            revert InvalidPermission();
        }

        // check if target address is allowed to be called
        if (flags.hasAllowedTargets && !$modulePermissions.allowedTargets.contains(target)) {
            revert InvalidPermission();
        }

        // check if target functioni is allowed to be called
        if (
            flags.hasAllowedFunctions
                && !$modulePermissions.allowedFunctions.contains(bytes32(functionSig))
        ) {
            revert InvalidPermission();
        }
    }

    function onExecuteBatch(
        address superVisorModule,
        Execution[] calldata
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onExecuteFromExecutor(
        address superVisorModule,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onExecuteBatchFromExecutor(
        address superVisorModule,
        Execution[] calldata
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onInstallModule(
        address superVisorModule,
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onUninstallModule(
        address superVisorModule,
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onPostCheck(bytes calldata hookData)
        external
        virtual
        override
        returns (bool success)
    { }
}
