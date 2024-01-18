// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { RhinestoneAccount, UserOpData } from "./RhinestoneModuleKit.sol";
import { IERC7579Execution, IERC7579Config } from "../external/ERC7579.sol";
import { UserOperation } from "../external/ERC4337.sol";
import { ERC7579Helpers } from "./utils/ERC7579Helpers.sol";
import { ExtensibleFallbackHandler } from "../core/ExtensibleFallbackHandler.sol";
import { ModuleKitUserOp } from "./ModuleKitUserOp.sol";
import { ModuleKitHelpers } from "./ModuleKitHelpers.sol";
import { ISessionKeyManager, ISessionValidationModule } from "../Core.sol";

library ModuleKitSCM {
    using ModuleKitUserOp for RhinestoneAccount;
    using ModuleKitHelpers for RhinestoneAccount;
    /**
     * @dev Installs core/SessionKeyManager on the account if not already installed, and
     * configures it with the given sessionKeyModule and sessionKeyData
     *
     * @param instance RhinestoneAccount
     * @param sessionKeyModule the SessionKeyManager SessionKeyModule address that will handle this
     * sessionkeyData
     * @param validUntil timestamp until which the sessionKey is valid
     * @param validAfter timestamp after which the sessionKey is valid
     * @param sessionKeyData bytes encoded data that will be passed to the sessionKeyModule
     */

    function installSessionKey(
        RhinestoneAccount memory instance,
        address sessionKeyModule,
        uint48 validUntil,
        uint48 validAfter,
        bytes memory sessionKeyData
    )
        internal
        returns (UserOpData memory userOpData, bytes32 sessionKeyDigest)
    {
        IERC7579Execution.Execution[] memory executions;

        // detect if account was not created yet, or if SessionKeyManager is not installed
        if (
            instance.initCode.length > 0
                || !instance.isValidatorInstalled(address(instance.aux.sessionKeyManager))
        ) {
            executions = new IERC7579Execution.Execution[](2);
            // install core/SessionKeyManager first
            executions[0] = IERC7579Execution.Execution({
                target: instance.account,
                value: 0,
                callData: ERC7579Helpers.configModule(
                    instance.account,
                    address(instance.aux.sessionKeyManager),
                    "",
                    ERC7579Helpers.installValidator // <--
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
        executions[executions.length - 1] = IERC7579Execution.Execution({
            target: address(instance.aux.sessionKeyManager),
            value: 0,
            callData: abi.encodeCall(ISessionKeyManager.enableSession, (sessionData))
        });

        userOpData = instance.getExecOps(executions, address(instance.defaultValidator));
        sessionKeyDigest = instance.aux.sessionKeyManager.digest(sessionData);
    }

    function getExecOps(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes32 sessionKeyDigest,
        bytes memory sessionKeySignature
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData =
            instance.getExecOps(target, value, callData, address(instance.defaultValidator));
        bytes1 MODE_USE = 0x00;
        bytes memory signature =
            abi.encodePacked(MODE_USE, abi.encode(sessionKeyDigest, sessionKeySignature));
        userOpData.userOp.signature = signature;
    }

    // wrapper for signAndExec4337
    function getExecOps(
        RhinestoneAccount memory instance,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas,
        bytes32[] memory sessionKeyDigests,
        bytes[] memory sessionKeySignatures
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.getExecOps(
            ERC7579Helpers.toExecutions(targets, values, callDatas),
            address(instance.defaultValidator)
        );
        bytes1 MODE_USE = 0x00;
        bytes memory signature =
            abi.encodePacked(MODE_USE, abi.encode(sessionKeyDigests, sessionKeySignatures));
        userOpData.userOp.signature = signature;
    }
}
