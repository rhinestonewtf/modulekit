// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccountInstance, UserOpData } from "./RhinestoneModuleKit.sol";
import { ERC7579Helpers } from "./utils/ERC7579Helpers.sol";
import { Execution } from "../external/ERC7579.sol";

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
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            moduleType: moduleType,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.installModule,
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
        (userOpData.userOp, userOpData.userOpHash) = ERC7579Helpers.configModuleUserOp({
            instance: instance,
            moduleType: moduleType,
            module: module,
            initData: initData,
            fn: ERC7579Helpers.uninstallModule,
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
        AccountInstance memory instance,
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
        AccountInstance memory instance,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas,
        address txValidator
    )
        internal
        view
        returns (UserOpData memory userOpData)
    {
        Execution[] memory executions = ERC7579Helpers.toExecutions(targets, values, callDatas);
        return getExecOps(instance, executions, txValidator);
    }
}
