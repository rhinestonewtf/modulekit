// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {
    IERC7579Account,
    ERC7579Account,
    ERC7579AccountFactory,
    ERC7579Bootstrap,
    ERC7579BootstrapConfig,
    IERC7579Validator,
    IERC7579Config,
    IERC7579Execution,
    IERC7579ConfigHook
} from "../external/ERC7579.sol";

import { ERC7579Helpers } from "./utils/ERC7579Helpers.sol";
import { ERC4337Helpers } from "./utils/ERC4337Helpers.sol";
import { UserOperation } from "../external/ERC4337.sol";
import { IEntryPoint, Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";
import "./utils/BootstrapUtil.sol";
import "./utils/Vm.sol";
import "./utils/Log.sol";
import "../mocks/MockValidator.sol";
import { ISessionKeyManager, SessionData } from "../core/SessionKey/ISessionKeyManager.sol";
import { ISessionValidationModule } from "../core/SessionKey/ISessionValidationModule.sol";
import { ExtensibleFallbackHandler } from "../core/ExtensibleFallbackHandler.sol";
import "forge-std/console2.sol";

interface GasDebug {
    function getGasConsumed(address acccount, uint256 phase) external view returns (uint256);
}

struct RhinestoneAccount {
    address account;
    IERC7579Validator defaultValidator;
    Auxiliary aux;
    bytes32 salt;
    bytes initCode;
}

contract RhinestoneModuleKit is AuxiliaryFactory, BootstrapUtil {
    ERC7579AccountFactory public accountFactory;
    ERC7579Account public accountImplementationSingleton;

    using ERC4337Helpers for *;

    bool isInit;

    uint256 singNonce;

    MockValidator public defaultValidator;

    constructor() {
        init();
    }

    function init() internal virtual override {
        if (!isInit) {
            super.init();
            isInit = true;
        }

        isInit = true;
        accountImplementationSingleton = new ERC7579Account();
        label(address(accountImplementationSingleton), "ERC7579AccountImpl");
        accountFactory = new ERC7579AccountFactory(address(accountImplementationSingleton));
        label(address(accountFactory), "ERC7579AccountFactory");
        defaultValidator = new  MockValidator();
        label(address(defaultValidator), "DefaultValidator");
    }

    function makeRhinestoneAccount(
        bytes32 salt,
        address counterFactualAddress,
        bytes memory initCode4337
    )
        internal
        returns (RhinestoneAccount memory instance)
    {
        instance = RhinestoneAccount({
            account: counterFactualAddress,
            aux: auxiliary,
            salt: salt,
            defaultValidator: IERC7579Validator(address(defaultValidator)),
            initCode: initCode4337
        });
    }

    function makeRhinestoneAccount(
        bytes32 salt,
        ERC7579BootstrapConfig[] memory validators,
        ERC7579BootstrapConfig[] memory executors,
        ERC7579BootstrapConfig memory hook,
        ERC7579BootstrapConfig memory fallBack
    )
        internal
        returns (RhinestoneAccount memory instance)
    {
        bytes memory bootstrapCalldata =
            auxiliary.bootstrap._getInitMSACalldata(validators, executors, hook, fallBack);
        address account = accountFactory.getAddress(salt, bootstrapCalldata);

        bytes memory createAccountOnFactory =
            abi.encodeCall(accountFactory.createAccount, (salt, bootstrapCalldata));

        address factory = address(accountFactory);

        bytes memory initCode4337 = abi.encodePacked(factory, createAccountOnFactory);
        label(address(account), bytes32ToString(salt));
        deal(account, 1 ether);
        instance = makeRhinestoneAccount(salt, account, initCode4337);
        instance.defaultValidator = IERC7579Validator(validators[0].module);
    }

    function makeRhinestoneAccount(bytes32 salt)
        internal
        returns (RhinestoneAccount memory instance)
    {
        ERC7579BootstrapConfig[] memory validators =
            makeBootstrapConfig(address(defaultValidator), "");

        ERC7579BootstrapConfig[] memory executors = _emptyConfigs();

        ERC7579BootstrapConfig memory hook = _emptyConfig();

        ERC7579BootstrapConfig memory fallBack = _emptyConfig();
        instance = makeRhinestoneAccount(salt, validators, executors, hook, fallBack);
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        bytes memory _bytes = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            _bytes[i] = _bytes32[i];
        }
        return string(_bytes);
    }
}

library RhinestoneModuleKitLib {
    using ERC4337Helpers for *;
    using ERC7579Helpers for *;

    function installValidator(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        returns (bytes32 userOpHash)
    {
        return installValidator(instance, validator, "");
    }

    function installValidator(
        RhinestoneAccount memory instance,
        address validator,
        bytes memory initData
    )
        internal
        returns (bytes32 userOpHash)
    {
        UserOperation memory userOp = toUserOp({
            instance: instance,
            callData: instance.account.configModule(
                validator,
                initData,
                ERC7579Helpers.installValidator // <--
            )
        });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });
    }

    function uninstallValidator(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        returns (bytes32 userOpHash)
    {
        return uninstallValidator(instance, validator, "");
    }

    function uninstallValidator(
        RhinestoneAccount memory instance,
        address validator,
        bytes memory initData
    )
        internal
        returns (bytes32 userOpHash)
    {
        UserOperation memory userOp = toUserOp({
            instance: instance,
            callData: instance.account.configModule(
                validator,
                initData,
                ERC7579Helpers.uninstallValidator // <--
            )
        });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });
    }

    function installExecutor(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        returns (bytes32 userOpHash)
    {
        return installExecutor(instance, executor, "");
    }

    function installExecutor(
        RhinestoneAccount memory instance,
        address executor,
        bytes memory initData
    )
        internal
        returns (bytes32 userOpHash)
    {
        UserOperation memory userOp = toUserOp({
            instance: instance,
            callData: instance.account.configModule(executor, initData, ERC7579Helpers.installExecutor) // <--
         });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });
    }

    function uninstallExecutor(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        returns (bytes32 userOpHash)
    {
        return uninstallExecutor(instance, executor, "");
    }

    function uninstallExecutor(
        RhinestoneAccount memory instance,
        address executor,
        bytes memory initData
    )
        internal
        returns (bytes32 userOpHash)
    {
        UserOperation memory userOp = toUserOp({
            instance: instance,
            callData: instance.account.configModule(
                executor,
                initData,
                ERC7579Helpers.uninstallExecutor // <--
            )
        });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });
    }

    function installHook(
        RhinestoneAccount memory instance,
        address hook
    )
        internal
        returns (bytes32 userOpHash)
    {
        return installHook(instance, hook, "");
    }

    function installHook(
        RhinestoneAccount memory instance,
        address hook,
        bytes memory initData
    )
        internal
        returns (bytes32 userOpHash)
    {
        UserOperation memory userOp = toUserOp({
            instance: instance,
            callData: instance.account.configModule(
                hook,
                initData,
                ERC7579Helpers.installHook // <--
            )
        });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });
    }

    function uninstallHook(
        RhinestoneAccount memory instance,
        address hook
    )
        internal
        returns (bytes32 userOpHash)
    {
        return uninstallHook(instance, hook, "");
    }

    function uninstallHook(
        RhinestoneAccount memory instance,
        address hook,
        bytes memory initData
    )
        internal
        returns (bytes32 userOpHash)
    {
        UserOperation memory userOp = toUserOp({
            instance: instance,
            callData: instance.account.configModule(
                hook,
                initData,
                ERC7579Helpers.uninstallHook // <--
            )
        });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });
    }

    function isHookInstalled(
        RhinestoneAccount memory instance,
        address hook
    )
        internal
        view
        returns (bool isEnabled)
    {
        return IERC7579ConfigHook(instance.account).isHookInstalled(hook);
    }

    function installFallback(
        RhinestoneAccount memory instance,
        bytes4 handleFunctionSig,
        bool isStatic,
        address handler
    )
        internal
        returns (bytes32 userOpHash)
    {
        // check if fallbackhandler is installed on account

        bool enabled = IERC7579Config(instance.account).isFallbackInstalled(
            address(instance.aux.fallbackHandler)
        );

        IERC7579Execution.Execution[] memory executions;

        if (!enabled) {
            executions = new IERC7579Execution.Execution[](2);

            executions[0] = IERC7579Execution.Execution({
                target: instance.account,
                value: 0,
                callData: instance.account.configModule(
                    address(instance.aux.fallbackHandler),
                    "",
                    ERC7579Helpers.installFallback // <--
                )
            });
        } else {
            executions = new IERC7579Execution.Execution[](1);
        }

        ExtensibleFallbackHandler.FallBackType fallbackType = isStatic
            ? ExtensibleFallbackHandler.FallBackType.Static
            : ExtensibleFallbackHandler.FallBackType.Dynamic;

        ExtensibleFallbackHandler.Params memory params = ExtensibleFallbackHandler.Params({
            selector: handleFunctionSig,
            fallbackType: fallbackType,
            handler: handler
        });

        executions[executions.length - 1] = IERC7579Execution.Execution({
            target: address(instance.aux.fallbackHandler),
            value: 0,
            callData: abi.encodeCall(ExtensibleFallbackHandler.setFunctionSig, (params))
        });

        UserOperation memory userOp =
            toUserOp({ instance: instance, callData: executions.encodeExecution() });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });

        emit ModuleKitLogs.ModuleKit_SetFallback(instance.account, handleFunctionSig, handler);
    }

    function installSessionKey(
        RhinestoneAccount memory instance,
        address sessionKeyModule,
        uint48 validUntil,
        uint48 validAfter,
        bytes memory sessionKeyData
    )
        internal
        returns (bytes32 sessionKeyDigest)
    {
        // check if SessionKeyManager is installed as IERC7579Validator
        bool requireSessionKeyInstallation =
            !isValidatorInstalled(instance, address(instance.aux.sessionKeyManager));
        if (requireSessionKeyInstallation) {
            installValidator(instance, address(instance.aux.sessionKeyManager));
        }

        SessionData memory sessionData = SessionData({
            validUntil: validUntil,
            validAfter: validAfter,
            sessionValidationModule: ISessionValidationModule(sessionKeyModule),
            sessionKeyData: sessionKeyData
        });

        // enable sessionKey
        exec4337(
            instance,
            address(instance.aux.sessionKeyManager),
            abi.encodeCall(ISessionKeyManager.enableSession, (sessionData))
        );

        // get sessionKey digest
        sessionKeyDigest = instance.aux.sessionKeyManager.digest(sessionData);
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes32 sessionKeyDigest,
        bytes memory sessionKeySignature
    )
        internal
        returns (bytes32 userOpHash)
    {
        bytes memory singleExec = ERC7579Helpers.encodeExecution(target, value, callData);
        UserOperation memory userOp = toUserOp({ instance: instance, callData: singleExec });
        bytes1 MODE_USE = 0x00;
        bytes memory signature =
            abi.encodePacked(MODE_USE, abi.encode(sessionKeyDigest, sessionKeySignature));

        return signAndExec4337(instance, userOp, address(instance.aux.sessionKeyManager), signature);
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas,
        bytes32[] memory sessionKeyDigests,
        bytes[] memory sessionKeySignatures
    )
        internal
        returns (bytes32 userOpHash)
    {
        bytes1 MODE_USE = 0x00;
        bytes memory signature =
            abi.encodePacked(MODE_USE, abi.encode(sessionKeyDigests, sessionKeySignatures));

        bytes memory batchedTx = ERC7579Helpers.encodeExecution(targets, values, callDatas);
        UserOperation memory userOp = toUserOp({ instance: instance, callData: batchedTx });

        return signAndExec4337(instance, userOp, address(instance.aux.sessionKeyManager), signature);
    }

    function signAndExec4337(
        RhinestoneAccount memory instance,
        UserOperation memory userOp,
        address validator,
        bytes memory signature
    )
        internal
        returns (bytes32 userOpHash)
    {
        (userOpHash, userOp) = ERC7579Helpers.signUserOp(
            instance.account, instance.aux.entrypoint, userOp, validator, signature
        );

        ERC4337Helpers.exec4337(instance.account, instance.aux.entrypoint, userOp);
    }

    function exec4337(
        RhinestoneAccount memory instance,
        UserOperation memory userOp,
        address validator,
        bytes memory signature
    )
        internal
        returns (bytes32 userOpHash)
    {
        return signAndExec4337(instance, userOp, validator, signature);
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        bytes memory callData
    )
        internal
        returns (bytes32 userOpHash)
    {
        return exec4337(instance, target, 0, callData, address(instance.defaultValidator), "");
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes32 userOpHash)
    {
        return exec4337(instance, target, value, callData, address(instance.defaultValidator), "");
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        address validator,
        bytes memory signature
    )
        internal
        returns (bytes32 userOpHash)
    {
        bytes memory singleExec = ERC7579Helpers.encodeExecution(target, value, callData);
        UserOperation memory userOp = toUserOp({ instance: instance, callData: singleExec });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: validator,
            signature: signature
        });
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas
    )
        internal
        returns (bytes32 userOpHash)
    {
        return
            exec4337(instance, targets, values, callDatas, address(instance.defaultValidator), "");
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas,
        address validator,
        bytes memory signature
    )
        internal
        returns (bytes32 userOpHash)
    {
        IERC7579Execution.Execution[] memory executions =
            ERC7579Helpers.toExecutions(targets, values, callDatas);
        bytes memory batchedCallData = executions.encodeExecution();
        UserOperation memory userOp = toUserOp({ instance: instance, callData: batchedCallData });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: validator,
            signature: signature
        });
    }

    function exec4337(
        RhinestoneAccount memory instance,
        IERC7579Execution.Execution[] memory executions
    )
        internal
        returns (bytes32 userOpHash)
    {
        return exec4337(instance, executions, address(instance.defaultValidator), "");
    }

    function exec4337(
        RhinestoneAccount memory instance,
        IERC7579Execution.Execution[] memory executions,
        address validator,
        bytes memory signature
    )
        internal
        returns (bytes32 userOpHash)
    {
        bytes memory batchedCallData = executions.encodeExecution();
        UserOperation memory userOp = toUserOp({ instance: instance, callData: batchedCallData });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: validator,
            signature: signature
        });
    }

    function expect4337Revert(RhinestoneAccount memory) internal {
        writeExpectRevert(1);
    }

    function log4337Gas(
        RhinestoneAccount memory instance,
        string memory name
    )
        internal
        view
        returns (uint256 gasValidation, uint256 gasExecution)
    {
        gasValidation =
            GasDebug(address(instance.aux.entrypoint)).getGasConsumed(instance.account, 1);
        gasExecution =
            GasDebug(address(instance.aux.entrypoint)).getGasConsumed(instance.account, 2);

        console2.log("\nERC-4337 Gas Log:", name);
        console2.log("Verification:  ", gasValidation);
        console2.log("Execution:     ", gasExecution);
    }

    /**
     * @dev Checks if a validator is enabled
     *
     * @param instance RhinestoneAccount
     * @param validator Validator address
     *
     * @return isEnabled True if validator is enabled
     */
    function isValidatorInstalled(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        view
        returns (bool isEnabled)
    {
        return IERC7579Config(instance.account).isValidatorInstalled(validator);
    }

    /**
     * @dev Checks if an executor is enabled
     *
     * @param instance RhinestoneAccount
     * @param executor Executor address
     *
     * @return isEnabled True if executor is enabled
     */
    function isExecutorInstalled(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        view
        returns (bool isEnabled)
    {
        return IERC7579Config(instance.account).isExecutorInstalled(executor);
    }

    function hashUserOp(
        RhinestoneAccount memory instance,
        UserOperation memory userOp
    )
        internal
        returns (bytes32)
    {
        bytes32 userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
        return userOpHash;
    }

    function toUserOp(
        RhinestoneAccount memory instance,
        bytes memory callData
    )
        internal
        view
        returns (UserOperation memory userOp)
    {
        bool alreadyDeployed = instance.account.code.length > 0;
        if (alreadyDeployed) {
            instance.initCode = "";
        }

        userOp = UserOperation({
            sender: instance.account,
            nonce: 0,
            initCode: instance.initCode,
            callData: callData,
            callGasLimit: 2e6,
            verificationGasLimit: 2e6,
            preVerificationGas: 2e6,
            maxFeePerGas: 1,
            maxPriorityFeePerGas: 1,
            paymasterAndData: bytes(""),
            signature: bytes("")
        });
    }
}
