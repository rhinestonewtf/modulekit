// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccountInstance, UserOpData } from "./RhinestoneModuleKit.sol";
import { IEntryPoint } from "../external/ERC4337.sol";
import { ModuleKitUserOp } from "./ModuleKitUserOp.sol";
import { ERC4337Helpers } from "./utils/ERC4337Helpers.sol";
import { ModuleKitCache } from "./utils/ModuleKitCache.sol";
import { writeExpectRevert, writeGasIdentifier } from "./utils/Log.sol";
import "./utils/Vm.sol";
import { HelperBase } from "./helpers/HelperBase.sol";
import { Execution } from "../external/ERC7579.sol";

library ModuleKitHelpers {
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
        data = getInstallModuleData(instance, moduleTypeId, module, data);
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
        data = getUninstallModuleData(instance, moduleTypeId, module, data);
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
        return HelperBase(instance.accountHelper).isModuleInstalled(instance, moduleTypeId, module);
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
        return HelperBase(instance.accountHelper).isModuleInstalled(
            instance, moduleTypeId, module, data
        );
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
        writeExpectRevert(1);
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
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        view
        returns (bytes memory)
    {
        return HelperBase(instance.accountHelper).getInstallModuleData(
            instance, moduleTypeId, module, data
        );
    }

    function getUninstallModuleData(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        view
        returns (bytes memory)
    {
        return HelperBase(instance.accountHelper).getUninstallModuleData(
            instance, moduleTypeId, module, data
        );
    }

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
        (userOpData.userOp, userOpData.userOpHash) = HelperBase(instance.accountHelper)
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
        (userOpData.userOp, userOpData.userOpHash) = HelperBase(instance.accountHelper)
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
        bytes memory erc7579ExecCall =
            HelperBase(instance.accountHelper).encode(target, value, callData);
        (userOpData.userOp, userOpData.userOpHash) = HelperBase(instance.accountHelper).execUserOp({
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
        returns (UserOpData memory userOpData)
    {
        bytes memory erc7579ExecCall = HelperBase(instance.accountHelper).encode(executions);
        (userOpData.userOp, userOpData.userOpHash) = HelperBase(instance.accountHelper).execUserOp({
            instance: instance,
            callData: erc7579ExecCall,
            txValidator: txValidator
        });
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
    //         HelperBase(instance.accountHelper).toExecutions(targets, values, callDatas);
    //     return getExecOps(instance, executions, txValidator);
    // }
}
