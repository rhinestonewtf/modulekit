// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookDestruct } from "@rhinestone/modulekit/src/modules/ERC7579HookDestruct.sol";
import { Execution, IERC7579Account } from "@rhinestone/modulekit/src/Accounts.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract PermissionsHook is ERC7579HookDestruct {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidPermission();

    struct ModulePermissions {
        // Execution permissions
        // - Target permissions
        bool selfCall;
        bool moduleCall;
        bool hasAllowedTargets;
        // - Value permissions
        bool sendValue;
        // - Calldata permissions
        bool hasAllowedFunctions;
        bool erc20Transfer;
        bool erc721Transfer;
        // Module configuration permissions
        bool moduleConfig;
        bytes4[] allowedFunctions;
        address[] allowedTargets;
    }

    mapping(address account => mapping(address module => ModulePermissions)) internal permissions;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        (address[] memory _modules, ModulePermissions[] memory _permissions) =
            abi.decode(data, (address[], ModulePermissions[]));

        uint256 permissionsLength = _permissions.length;

        if (_modules.length != permissionsLength) {
            revert("PermissionsHook: addPermissions: module and permissions length mismatch");
        }

        for (uint256 i = 0; i < permissionsLength; i++) {
            permissions[msg.sender][_modules[i]] = _permissions[i];
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
        ModulePermissions[] calldata _permissions
    )
        external
    {
        uint256 permissionsLength = _permissions.length;

        if (_modules.length != permissionsLength) {
            revert("PermissionsHook: addPermissions: module and permissions length mismatch");
        }

        for (uint256 i = 0; i < permissionsLength; i++) {
            permissions[msg.sender][_modules[i]] = _permissions[i];
        }
    }

    function getPermissions(
        address account,
        address module
    )
        public
        view
        returns (ModulePermissions memory)
    {
        return permissions[account][module];
    }

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
        // Not callable from module
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
        ModulePermissions memory modulePermissions = permissions[msg.sender][msgSender];
        _validateExecutePermissions(modulePermissions, target, value, callData);
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
        ModulePermissions memory modulePermissions = permissions[msg.sender][msgSender];

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

        ModulePermissions storage modulePermissions = permissions[msg.sender][msgSender];

        if (!modulePermissions.moduleConfig) {
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

        ModulePermissions storage modulePermissions = permissions[msg.sender][msgSender];

        if (!modulePermissions.moduleConfig) {
            revert InvalidPermission();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _validateExecutePermissions(
        ModulePermissions memory modulePermissions,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
    {
        // Target permissions
        if (target == msg.sender && !modulePermissions.selfCall) {
            revert InvalidPermission();
        }

        if (!modulePermissions.moduleCall) {
            if (IERC7579Account(msg.sender).isModuleInstalled(TYPE_EXECUTOR, target, "")) {
                revert InvalidPermission();
            }
        }

        if (modulePermissions.hasAllowedTargets) {
            bool isAllowedTarget = false;
            uint256 allowedTargetsLength = modulePermissions.allowedTargets.length;
            for (uint256 i = 0; i < allowedTargetsLength; i++) {
                if (modulePermissions.allowedTargets[i] == target) {
                    isAllowedTarget = true;
                    break;
                }
            }

            if (!isAllowedTarget) {
                revert InvalidPermission();
            }
        }

        // Value permissions
        if (value > 0 && !modulePermissions.sendValue) {
            revert InvalidPermission();
        }

        // Calldata permissions
        if (_isErc20Transfer(callData) && !modulePermissions.erc20Transfer) {
            revert InvalidPermission();
        }

        if (_isErc721Transfer(callData) && !modulePermissions.erc721Transfer) {
            revert InvalidPermission();
        }

        if (modulePermissions.hasAllowedFunctions) {
            bool isAllowedFunction = false;
            uint256 allowedFunctionsLength = modulePermissions.allowedFunctions.length;
            for (uint256 i = 0; i < allowedFunctionsLength; i++) {
                if (modulePermissions.allowedFunctions[i] == bytes4(callData[0:4])) {
                    isAllowedFunction = true;
                    break;
                }
            }

            if (!isAllowedFunction) {
                revert InvalidPermission();
            }
        }
    }

    function _isErc20Transfer(bytes calldata callData)
        internal
        pure
        returns (bool isErc20Transfer)
    {
        if (callData.length < 4) {
            return false;
        }
        bytes4 functionSig = bytes4(callData[0:4]);
        if (functionSig == IERC20.transfer.selector || functionSig == IERC20.transferFrom.selector)
        {
            isErc20Transfer = true;
        }
    }

    function _isErc721Transfer(bytes calldata callData)
        internal
        pure
        returns (bool isErc721Transfer)
    {
        if (callData.length < 4) {
            return false;
        }
        bytes4 functionSig = bytes4(callData[0:4]);
        if (functionSig == IERC721.transferFrom.selector) {
            isErc721Transfer = true;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual returns (string memory) {
        return "ColdStorageHook";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_HOOK;
    }
}
