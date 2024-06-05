// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccountInstance, UserOpData } from "./RhinestoneModuleKit.sol";
import { IAccountHelpers } from "./helpers/IAccountHelpers.sol";
import { Execution, ERC7579ExecutionLib } from "../external/ERC7579.sol";
import { ERC7579Helpers } from "./helpers/ERC7579Helpers.sol";

library ModuleKitUserOp {
    function getInstallModuleOps(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = IAccountHelpers(instance.accountHelper)
            .configModuleUserOp({
            instance: instance,
            moduleType: moduleType,
            module: module,
            initData: initData,
            isInstall: true,
            txValidator: txValidator
        });
    }

    function getUninstallModuleOps(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = IAccountHelpers(instance.accountHelper)
            .configModuleUserOp({
            instance: instance,
            moduleType: moduleType,
            module: module,
            initData: initData,
            isInstall: false,
            txValidator: txValidator
        });
    }

    function getExecOps(
        AccountInstance memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        bytes memory erc7579ExecCall = ERC7579ExecutionLib.encodeSingle(target, value, callData);
        (userOpData.userOp, userOpData.userOpHash) = IAccountHelpers(instance.accountHelper)
            .execUserOp({ instance: instance, callData: erc7579ExecCall, txValidator: txValidator });
    }

    function getExecOps(
        AccountInstance memory instance,
        Execution[] memory executions,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        bytes memory erc7579ExecCall = ERC7579ExecutionLib.encodeBatch(executions);
        (userOpData.userOp, userOpData.userOpHash) = IAccountHelpers(instance.accountHelper)
            .execUserOp({ instance: instance, callData: erc7579ExecCall, txValidator: txValidator });
    }

    // function getExecOps(
    //     AccountInstance memory instance,
    //     address[] memory targets,
    //     uint256[] memory values,
    //     bytes[] memory callDatas,
    //     address txValidator
    // )
    //     internal
    //     view
    //     returns (UserOpData memory userOpData)
    // {
    //     Execution[] memory executions =
    //         IAccountHelpers(instance.accountHelper).toExecutions(targets, values, callDatas);
    //     return getExecOps(instance, executions, txValidator);
    // }
}
