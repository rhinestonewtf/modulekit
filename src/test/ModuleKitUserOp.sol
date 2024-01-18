// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { RhinestoneAccount, UserOpData } from "./RhinestoneModuleKit.sol";
import { UserOperation } from "../external/ERC4337.sol";
import { ERC7579Helpers } from "./utils/ERC7579Helpers.sol";
import { IERC7579Execution } from "../external/ERC7579.sol";

library ModuleKitUserOp {
    function installValidator(
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

    function uninstallValidator(
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

    function installExecutor(
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

    function uninstallExecutor(
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

    function installHook(
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

    function uninstallHook(
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

    function installFallback(
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

    function uninstallFallback(
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

    function exec(
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

    function exec(
        RhinestoneAccount memory instance,
        IERC7579Execution.Execution[] memory executions,
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

    function exec(
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
        IERC7579Execution.Execution[] memory executions =
            ERC7579Helpers.toExecutions(targets, values, initDatas);
        return exec(instance, executions, txValidator);
    }
}
