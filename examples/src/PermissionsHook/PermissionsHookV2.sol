// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookDestruct } from "@rhinestone/modulekit/src/modules/ERC7579HookDestruct.sol";
import { Execution, IERC7579Account } from "@rhinestone/modulekit/src/Accounts.sol";
import { IERC7579Module } from "@rhinestone/modulekit/src/Modules.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { LinkedBytes32Lib } from "sentinellist/SentinelListBytes32.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { HookMultiPlexer } from "./HookMultiplexer.sol";
import { TransactionDetectionLib } from "./TransactionDetectionLib.sol";

import "forge-std/console2.sol";

contract PermissionsHook is ERC7579HookDestruct, HookMultiPlexer {
    using SentinelListLib for SentinelListLib.SentinelList;
    using LinkedBytes32Lib for LinkedBytes32Lib.LinkedBytes32;
    using TransactionDetectionLib for bytes4;
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidPermission();

    struct InitParams {
        PermissionFlags flags;
        address[] allowedTargets;
        bytes32[] allowedFunctions;
        address[] moduleSubHooks;
    }

    struct PermissionFlags {
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
        PermissionFlags flags;
        LinkedBytes32Lib.LinkedBytes32 allowedFunctions;
        SentinelListLib.SentinelList allowedTargets;
    }

    mapping(address account => mapping(address module => ModulePermissions)) internal permissions;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        (address[] memory _modules, PermissionFlags[] memory _initParams) =
            abi.decode(data, (address[], PermissionFlags[]));

        uint256 permissionsLength = _initParams.length;

        if (_modules.length != permissionsLength) {
            revert("PermissionsHook: addPermissions: module and permissions length mismatch");
        }

        $globalSubHooks[msg.sender].init();

        for (uint256 i; i < permissionsLength; i++) {
            permissions[msg.sender][_modules[i]].flags = _initParams[i];
            $moduleSubHooks[msg.sender][_modules[i]].init();
        }
    }

    function onUninstall(bytes calldata data) external override {
        // todo
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        // todo
    }

    function addPermissions(
        address[] calldata _modules,
        PermissionFlags[] calldata _PermissionFlags
    )
        external
    {
        uint256 permissionsLength = _PermissionFlags.length;

        if (_modules.length != permissionsLength) {
            revert("PermissionsHook: addPermissions: module and permissions length mismatch");
        }

        for (uint256 i; i < permissionsLength; i++) {
            permissions[msg.sender][_modules[i]].flags = _PermissionFlags[i];
        }
    }

    // function getPermissions(
    //     address account,
    //     address module
    // )
    //     public
    //     view
    //     returns (ModulePermissions memory)
    // {
    //     return permissions[account][module];
    // }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function onPostCheck(bytes calldata hookData)
        internal
        virtual
        override
        returns (bool success)
    {
        return true;
    }

    function onExecute(
        address sourceModule,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        // Not callable from module
        ModulePermissions storage $permissions = permissions[msg.sender][sourceModule];
        console2.log("onExecute");
        _validateExecutePermissions($permissions, target, value, callData);
        console2.log("validated Permisisons");

        _onExecSubHooks(sourceModule, target, value, callData);
    }

    function onExecuteBatch(
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        // Not callable from module
    }

    function onExecuteFromExecutor(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        // ModulePermissions memory modulePermissions = permissions[msg.sender][msgSender];
        // _validateExecutePermissions(modulePermissions, target, value, callData);
    }

    function onExecuteBatchFromExecutor(
        address msgSender,
        Execution[] calldata executions
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        ModulePermissions storage modulePermissions = permissions[msg.sender][msgSender];

        uint256 executionLength = executions.length;
        for (uint256 i = 0; i < executionLength; i++) {
            _validateExecutePermissions(
                modulePermissions, executions[i].target, executions[i].value, executions[i].callData
            );
        }
    }

    function onInstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        bool isInstalledExecutor =
            IERC7579Account(msg.sender).isModuleInstalled(TYPE_EXECUTOR, msgSender, "");

        if (!isInstalledExecutor) {
            // Execution not triggered by executor, so account should do access control
            return "";
        }

        ModulePermissions storage $permissions = permissions[msg.sender][msgSender];

        if (!$permissions.flags.moduleConfig) {
            revert InvalidPermission();
        }
    }

    function onUninstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        bool isInstalledExecutor =
            IERC7579Account(msg.sender).isModuleInstalled(TYPE_EXECUTOR, msgSender, "");

        if (!isInstalledExecutor) {
            // Execution not triggered by executor, so account should do access control
            return "";
        }

        ModulePermissions storage $permissions = permissions[msg.sender][msgSender];

        if (!$permissions.flags.moduleConfig) {
            revert InvalidPermission();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _validateExecutePermissions(
        ModulePermissions storage $permissions,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
    {
        PermissionFlags memory flags = $permissions.flags;

        bytes4 functionSig = callData.length > 4 ? bytes4(callData[0:4]) : bytes4(0);
        console2.log("validate exeute permissions");

        // check for self call
        if (!flags.selfCall && target == msg.sender) {
            revert InvalidPermission();
        }

        // check for module Call
        if (!flags.moduleCall) {
            // if (!flags.moduleCall && IERC7579Module(target).moduleId(msg.sender)) {
            revert InvalidPermission();
        }

        // check for value transfer
        if (!flags.sendValue && value > 0) {
            revert InvalidPermission();
        }

        // Calldata permissions
        if (!flags.erc20Transfer && functionSig.isERC20Transfer()) {
            revert InvalidPermission();
        }

        if (!flags.erc721Transfer && functionSig.isERC721Transfer()) {
            revert InvalidPermission();
        }

        // check if target address is allowed to be called
        if (flags.hasAllowedTargets && !$permissions.allowedTargets.contains(target)) {
            revert InvalidPermission();
        }

        // check if target functioni is allowed to be called
        if (
            flags.hasAllowedFunctions
                && !$permissions.allowedFunctions.contains(bytes32(functionSig))
        ) {
            revert InvalidPermission();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual returns (string memory) {
        return "PermissionHook";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_HOOK;
    }
}
