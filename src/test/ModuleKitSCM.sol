// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccountInstance, UserOpData } from "./RhinestoneModuleKit.sol";
import { IERC7579Account, Execution, MODULE_TYPE_VALIDATOR } from "../external/ERC7579.sol";
import { ERC7579Helpers } from "./utils/ERC7579Helpers.sol";
import { ExtensibleFallbackHandler } from "../core/ExtensibleFallbackHandler.sol";
import { ModuleKitUserOp } from "./ModuleKitUserOp.sol";
import { ModuleKitHelpers } from "./ModuleKitHelpers.sol";
import { ISessionKeyManager, ISessionValidationModule } from "../Core.sol";

library ModuleKitSCM {
    using ModuleKitUserOp for AccountInstance;
    using ModuleKitHelpers for AccountInstance;
    /**
     * @dev Installs core/SessionKeyManager on the account if not already installed, and
     * configures it with the given sessionKeyModule and sessionKeyData
     *
     * @param instance AccountInstance
     * @param sessionKeyModule the SessionKeyManager SessionKeyModule address that will handle this
     * sessionkeyData
     * @param validUntil timestamp until which the sessionKey is valid
     * @param validAfter timestamp after which the sessionKey is valid
     * @param sessionKeyData bytes encoded data that will be passed to the sessionKeyModule
     */

    function installSessionKey(
        AccountInstance memory instance,
        address sessionKeyModule,
        uint48 validUntil,
        uint48 validAfter,
        bytes memory sessionKeyData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData, bytes32 sessionKeyDigest)
    {
        Execution[] memory executions;

        // detect if account was not created yet, or if SessionKeyManager is not installed
        if (
            instance.initCode.length > 0
                || !instance.isModuleInstalled(
                    MODULE_TYPE_VALIDATOR, address(instance.aux.sessionKeyManager)
                )
        ) {
            executions = new Execution[](2);
            // install core/SessionKeyManager first
            executions[0] = Execution({
                target: instance.account,
                value: 0,
                callData: ERC7579Helpers.configModule(
                    instance.account,
                    MODULE_TYPE_VALIDATOR,
                    address(instance.aux.sessionKeyManager),
                    "",
                    ERC7579Helpers.installModule // <--
                )
            });
        }

        // configure SessionKeyManager/SessionData according to params
        ISessionKeyManager.SessionData memory sessionData = ISessionKeyManager.SessionData({
            validUntil: validUntil,
            validAfter: validAfter,
            sessionValidationModule: ISessionValidationModule(sessionKeyModule),
            sessionKeyData: sessionKeyData
        });

        // configure the sessionKeyData on the core/SessionKeyManager
        executions[executions.length - 1] = Execution({
            target: address(instance.aux.sessionKeyManager),
            value: 0,
            callData: abi.encodeCall(ISessionKeyManager.enableSession, (sessionData))
        });

        userOpData = instance.getExecOps(executions, txValidator);
        sessionKeyDigest = instance.aux.sessionKeyManager.digest(sessionData);
    }

    function getExecOps(
        AccountInstance memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes32 sessionKeyDigest,
        bytes memory sessionKeySignature,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.getExecOps(target, value, callData, txValidator);
        bytes1 MODE_USE = 0x00;
        bytes memory signature =
            abi.encodePacked(MODE_USE, abi.encode(sessionKeyDigest, sessionKeySignature));
        userOpData.userOp.signature = signature;
    }

    // wrapper for signAndExec4337
    function getExecOps(
        AccountInstance memory instance,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas,
        bytes32[] memory sessionKeyDigests,
        bytes[] memory sessionKeySignatures,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.getExecOps(
            ERC7579Helpers.toExecutions(targets, values, callDatas), txValidator
        );
        bytes1 MODE_USE = 0x00;
        bytes memory signature =
            abi.encodePacked(MODE_USE, abi.encode(sessionKeyDigests, sessionKeySignatures));
        userOpData.userOp.signature = signature;
    }
}
