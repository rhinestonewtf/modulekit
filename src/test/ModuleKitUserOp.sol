// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { RhinestoneAccount, UserOpData } from "./RhinestoneModuleKit.sol";
import { ERC7579Helpers } from "./utils/ERC7579Helpers.sol";
import { Execution } from "../external/ERC7579.sol";

library ModuleKitUserOp {
    function getInstallValidatorOps(
        RhinestoneAccount memory instance,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.installValidator,
            txValidator: txValidator
        });
    }

    function getUninstallValidatorOps(
        RhinestoneAccount memory instance,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.uninstallValidator,
            txValidator: txValidator
        });
    }

    function getInstallExecutorOps(
        RhinestoneAccount memory instance,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.installExecutor,
            txValidator: txValidator
        });
    }

    function getUninstallExecutorOps(
        RhinestoneAccount memory instance,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.uninstallExecutor,
            txValidator: txValidator
        });
    }

    function getInstallHookOps(
        RhinestoneAccount memory instance,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.installHook,
            txValidator: txValidator
        });
    }

    function getUninstallHookOps(
        RhinestoneAccount memory instance,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.uninstallHook,
            txValidator: txValidator
        });
    }

    function getInstallFallbackOps(
        RhinestoneAccount memory instance,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.installFallback,
            txValidator: txValidator
        });
    }

    function getUninstallFallbackOps(
        RhinestoneAccount memory instance,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.uninstallFallback,
            txValidator: txValidator
        });
    }

    function getExecOps(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        address txValidator
    )
        internal
        view
        returns (UserOpData memory userOpData)
    {
        bytes memory erc7579ExecCall = ERC7579Helpers.encode(target, value, callData);
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.execUserOp({
            instance: instance,
            callData: erc7579ExecCall,
            txValidator: txValidator
        });
    }

    function getExecOps(
        RhinestoneAccount memory instance,
        Execution[] memory executions,
        address txValidator
    )
        internal
        view
        returns (UserOpData memory userOpData)
    {
        bytes memory erc7579ExecCall = ERC7579Helpers.encode(executions);
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.execUserOp({
            instance: instance,
            callData: erc7579ExecCall,
            txValidator: txValidator
        });
    }

    function getExecOps(
        RhinestoneAccount memory instance,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory initDatas,
        address txValidator
    )
        internal
        view
        returns (UserOpData memory userOpData)
    {
        Execution[] memory executions = ERC7579Helpers.toExecutions(targets, values, initDatas);
        return getExecOps(instance, executions, txValidator);
    }
}
