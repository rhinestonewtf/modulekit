// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { RhinestoneAccount, UserOpData } from "./RhinestoneModuleKit.sol";
import { UserOperation, IEntryPoint } from "../external/ERC4337.sol";
import { IERC7579Account, IERC7579ConfigHook } from "../external/ERC7579.sol";
import { ModuleKitUserOp, UserOpData } from "./ModuleKitUserOp.sol";
import { ERC4337Helpers } from "./utils/ERC4337Helpers.sol";
import { ModuleKitCache } from "./utils/ModuleKitCache.sol";
import { writeExpectRevert } from "./utils/Log.sol";

library ModuleKitHelper {
    using ModuleKitUserOp for RhinestoneAccount;
    using ModuleKitHelper for UserOpData;

    // will call installValidator with initData:0

    function handleUserOp(UserOpData memory userOpData) internal {
        // send userOp to entrypoint

        IEntryPoint entrypoint = ModuleKitCache.getEntrypoint(userOpData.userOp.sender);
        ERC4337Helpers.exec4337(userOpData.userOp, entrypoint);
    }

    function signDefault(UserOpData memory userOpData) internal pure returns (UserOpData memory) {
        userOpData.userOp.signature = "DEFAULT SIGNATURE";
        return userOpData;
    }

    function installValidator(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.installValidator(module, "", address(instance.defaultValidator));
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.handleUserOp();
    }

    // will call uninstallValidator with initData:0
    function uninstallValidator(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.uninstallValidator(module, "", address(instance.defaultValidator));

        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.handleUserOp();
    }

    // will call installValidator with initData:0
    function installExecutor(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.installExecutor(module, "", address(instance.defaultValidator));

        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.handleUserOp();
    }

    // will call uninstallExecutor with initData:0
    function uninstallExecutor(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.uninstallExecutor(module, "", address(instance.defaultValidator));

        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.handleUserOp();
    }

    // executes installHook with initData:0
    function installHook(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.installHook(module, "", address(instance.defaultValidator));

        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.handleUserOp();
    }

    // executes uninstallHook with initData:0
    function uninstallHook(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.uninstallHook(module, "", address(instance.defaultValidator));
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.handleUserOp();
    }

    // executes installFallback with initData:0
    function installFallback(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.installFallback(module, "", address(instance.defaultValidator));
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.handleUserOp();
    }

    // executes installFallback wiith initData:0
    function uninstallFallback(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.installFallback(module, "", address(instance.defaultValidator));
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.handleUserOp();
    }

    function exec(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.exec(target, value, callData, address(instance.defaultValidator));
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        // send userOp to entrypoint
        userOpData.handleUserOp();
    }

    function exec(
        RhinestoneAccount memory instance,
        address target,
        bytes memory callData
    )
        internal
        returns (UserOpData memory userOpData)
    {
        return exec(instance, target, 0, callData);
    }

    function isValidatorInstalled(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (bool)
    {
        return IERC7579Account(instance.account).isValidatorInstalled(module);
    }

    function isExecutorInstalled(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (bool)
    {
        return IERC7579Account(instance.account).isExecutorInstalled(module);
    }

    function isHookInstalled(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (bool)
    {
        return IERC7579ConfigHook(instance.account).isHookInstalled(module);
    }

    function isFallbackInstalled(
        RhinestoneAccount memory instance,
        address module
    )
        internal
        returns (bool)
    {
        return IERC7579Account(instance.account).isFallbackInstalled(module);
    }

    function expect4337Revert(RhinestoneAccount memory) internal {
        writeExpectRevert(1);
    }
}
