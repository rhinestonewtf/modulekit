// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccountInstance, UserOpData } from "./RhinestoneModuleKit.sol";
import { IEntryPoint } from "../external/ERC4337.sol";
import {
    IERC7579Account,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_FALLBACK
} from "../external/ERC7579.sol";
import { ModuleKitUserOp, UserOpData } from "./ModuleKitUserOp.sol";
import { ERC4337Helpers } from "./utils/ERC4337Helpers.sol";
import { ModuleKitCache } from "./utils/ModuleKitCache.sol";
import { writeExpectRevert, writeGasIdentifier } from "./utils/Log.sol";
import { KernelHelpers } from "./utils/KernelHelpers.sol";
import "./utils/Vm.sol";
import { getAccountType, AccountType } from "src/accounts/MultiAccountHelpers.sol";
import { HookType } from "safe7579/DataTypes.sol";

library ModuleKitHelpers {
    using ModuleKitUserOp for AccountInstance;
    using ModuleKitHelpers for AccountInstance;
    using ModuleKitHelpers for UserOpData;

    function execUserOps(UserOpData memory userOpData) internal {
        // send userOp to entrypoint

        IEntryPoint entrypoint = ModuleKitCache.getEntrypoint(userOpData.userOp.sender);
        ERC4337Helpers.exec4337(userOpData.userOp, entrypoint);
    }

    function signDefault(UserOpData memory userOpData) internal pure returns (UserOpData memory) {
        userOpData.userOp.signature = "DEFAULT SIGNATURE";
        return userOpData;
    }

    function installModule(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        returns (UserOpData memory userOpData)
    {
        data = getInstallModuleData(moduleTypeId, module, data);
        userOpData = instance.getInstallModuleOps(
            moduleTypeId, module, data, address(instance.defaultValidator)
        );
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.execUserOps();
    }

    function uninstallModule(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        returns (UserOpData memory userOpData)
    {
        data = getUninstallModuleData(moduleTypeId, module, data);
        userOpData = instance.getUninstallModuleOps(
            moduleTypeId, module, data, address(instance.defaultValidator)
        );
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.execUserOps();
    }

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module
    )
        internal
        view
        returns (bool)
    {
        bytes memory data;
        AccountType env = getAccountType();
        if (env == AccountType.SAFE) {
            if (moduleTypeId == MODULE_TYPE_HOOK) {
                data = abi.encode(HookType.GLOBAL, bytes4(0x0), "");
            }
        } else if (env == AccountType.KERNEL) {
            if (moduleTypeId == MODULE_TYPE_HOOK) {
                return true;
            }
        }
        return isModuleInstalled(instance, moduleTypeId, module, data);
    }

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        view
        returns (bool)
    {
        AccountType env = getAccountType();
        if (env == AccountType.SAFE) {
            if (moduleTypeId == MODULE_TYPE_HOOK) {
                data = abi.encode(HookType.GLOBAL, bytes4(0x0), data);
            }
        } else if (env == AccountType.KERNEL) {
            if (moduleTypeId == MODULE_TYPE_HOOK) {
                return true;
            }
        }
        return IERC7579Account(instance.account).isModuleInstalled(moduleTypeId, module, data);
    }

    function exec(
        AccountInstance memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData =
            instance.getExecOps(target, value, callData, address(instance.defaultValidator));
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.execUserOps();
    }

    function exec(
        AccountInstance memory instance,
        address target,
        bytes memory callData
    )
        internal
        returns (UserOpData memory userOpData)
    {
        return exec(instance, target, 0, callData);
    }

    function deployAccount(AccountInstance memory instance) internal {
        if (instance.account.code.length == 0) {
            if (instance.initCode.length == 0) {
                revert("deployAccount: no initCode provided");
            } else {
                bytes memory initCode = instance.initCode;
                assembly {
                    let factory := mload(add(initCode, 20))
                    let success := call(gas(), factory, 0, add(initCode, 52), mload(initCode), 0, 0)
                    if iszero(success) { revert(0, 0) }
                }
            }
        }
    }

    function expect4337Revert(AccountInstance memory) internal {
        writeExpectRevert("");
    }

    function expect4337Revert(AccountInstance memory, bytes memory message) internal {
        writeExpectRevert(message);
    }

    function expect4337Revert(AccountInstance memory, bytes4 message) internal {
        writeExpectRevert(abi.encode(message));
    }

    /**
     * @dev Logs the gas used by an ERC-4337 transaction
     * @dev needs to be called before an exec4337 call
     * @dev the id needs to be unique across your tests, otherwise the gas calculations will
     * overwrite each other
     *
     * @param id Identifier for the gas calculation, which will be used as the filename
     */
    function log4337Gas(AccountInstance memory, /* instance */ string memory id) internal {
        writeGasIdentifier(id);
    }

    function getInstallModuleData(
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        view
        returns (bytes memory)
    {
        AccountType env = getAccountType();
        if (env == AccountType.KERNEL) {
            if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
                data = KernelHelpers.getDefaultInstallExecutorData(module, data);
            } else if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
                data = KernelHelpers.getDefaultInstallValidatorData(module, data);
            } else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
                data = KernelHelpers.getDefaultInstallFallbackData(module, data);
            } else {
                //TODO fix hook encoding impl in kernel helpers lib
                data = KernelHelpers.getDefaultInstallHookData(module, data);
            }
        }
        return data;
    }

    function getUninstallModuleData(
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        view
        returns (bytes memory)
    {
        AccountType env = getAccountType();
        if (env == AccountType.KERNEL) {
            if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
                data = KernelHelpers.getDefaultUninstallExecutorData(module, data);
            } else if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
                data = KernelHelpers.getDefaultUninstallValidatorData(module, data);
            } else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
                data = KernelHelpers.getDefaultUninstallFallbackData(module, data);
            } else {
                //TODO handle for hook
            }
        }
        return data;
    }
}
