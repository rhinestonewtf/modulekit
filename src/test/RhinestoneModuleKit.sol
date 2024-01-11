// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {
    ERC7579Account,
    ERC7579AccountFactory,
    ERC7579BootstrapConfig,
    IERC7579Validator,
    IERC7579Config,
    IERC7579Execution,
    IERC7579ConfigHook
} from "../external/ERC7579.sol";

import { ERC7579Helpers, BootstrapUtil } from "./utils/ERC7579Helpers.sol";
import { ERC4337Helpers } from "./utils/ERC4337Helpers.sol";
import { UserOperation } from "../external/ERC4337.sol";
import { Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";
import { MockValidator } from "../mocks/MockValidator.sol";
import { ISessionKeyManager, SessionData } from "../core/SessionKey/ISessionKeyManager.sol";
import { ISessionValidationModule } from "../core/SessionKey/ISessionValidationModule.sol";
import { ExtensibleFallbackHandler } from "../core/ExtensibleFallbackHandler.sol";

/* solhint-disable no-global-import */
// solhint-disable no-console
import "forge-std/console2.sol";
import "./utils/Vm.sol";
import "./utils/Log.sol";

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
    using RhinestoneModuleKitLib for RhinestoneAccount;
    using ERC4337Helpers for *;

    ERC7579AccountFactory public accountFactory;
    ERC7579Account public accountImplementationSingleton;

    bool internal isInit;

    MockValidator public defaultValidator;

    constructor() {
        init();
    }

    /**
     * Initializes Auxiliary and /src/core
     * This function will run before any accounts can be created
     */
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

    /**
     * create new RhinestoneAccount with initCode
     * @param salt account salt / name
     * @param counterFactualAddress of the account
     * @param initCode4337 to be added to userOp:initCode
     */
    function makeRhinestoneAccount(
        bytes32 salt,
        address counterFactualAddress,
        bytes memory initCode4337
    )
        internal
        returns (RhinestoneAccount memory instance)
    {
        // Create RhinestoneAccount struct with counterFactualAddress and initCode
        // The initcode will be set to 0, once the account was created by EntryPoint.sol
        instance = RhinestoneAccount({
            account: counterFactualAddress,
            aux: auxiliary,
            salt: salt,
            defaultValidator: IERC7579Validator(address(defaultValidator)),
            initCode: initCode4337
        });
    }

    /**
     * create new RhinestoneAccount with ERC7579BootstrapConfig
     *
     * @param salt account salt / name
     * @param validators ERC7549 validators to be installed on the account
     * @param executors ERC7549 executors to be installed on the account
     * @param hook ERC7549 hook to be installed on the account
     * @param fallBack ERC7549 fallbackHandler to be installed on the account
     */
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
        init();

        if (validators.length == 0) validators = new ERC7579BootstrapConfig[](1);

        // inject the defaultValidator if it is not already in the list
        // defaultValidator is used a lot in ModuleKit, to make it easier to use
        // if defaultValidator isnt available on the account, a lot of ModuleKit Abstractions would
        // break
        if (validators[0].module != address(0) && validators[0].module != address(defaultValidator))
        {
            ERC7579BootstrapConfig[] memory _validators =
                new ERC7579BootstrapConfig[](validators.length + 1);
            _validators[0] = ERC7579BootstrapConfig({ module: address(defaultValidator), data: "" });
            for (uint256 i = 0; i < validators.length; i++) {
                _validators[i + 1] = validators[i];
            }
            validators = _validators;
        }

        bytes memory bootstrapCalldata =
            auxiliary.bootstrap._getInitMSACalldata(validators, executors, hook, fallBack);
        address account = accountFactory.getAddress(salt, bootstrapCalldata);

        // using MSAFactory from ERC7579 repo.
        bytes memory createAccountOnFactory =
            abi.encodeCall(accountFactory.createAccount, (salt, bootstrapCalldata));

        address factory = address(accountFactory);
        // encode pack factory and account initCode to comply with SenderCreater (EntryPoint.sol)
        bytes memory initCode4337 = abi.encodePacked(factory, createAccountOnFactory);
        label(address(account), bytes32ToString(salt));
        deal(account, 1 ether);

        instance = makeRhinestoneAccount(salt, account, initCode4337);
    }

    /**
     * create new RhinestoneAccount with modulekit defaults
     *
     * @param salt account salt / name
     */
    function makeRhinestoneAccount(bytes32 salt)
        internal
        returns (RhinestoneAccount memory instance)
    {
        init();
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

/**
 * ERC7579 Native library that can be used by Module Developers.
 * This Library implements abstractions for account managements
 */
library RhinestoneModuleKitLib {
    using RhinestoneModuleKitLib for *;
    using ERC4337Helpers for *;
    using ERC7579Helpers for *;

    /*//////////////////////////////////////////////////////////////////////////
                                MANAGE MODULES ON ACCOUNT
    //////////////////////////////////////////////////////////////////////////*/

    // will call installValidator with initData:0
    function installValidator(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        returns (bytes32 userOpHash)
    {
        return installValidator(instance, validator, "");
    }

    /**
     * @dev installs a validator to the account
     *
     * @param instance RhinestoneAccount
     * @param validator ERC7579 Module address
     * @param initData bytes encoded initialization data.
     *       This data will be passed to the validator oninstall by the account
     */
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

    // executes uninstallValidator with initData:0
    function uninstallValidator(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        returns (bytes32 userOpHash)
    {
        return uninstallValidator(instance, validator, "");
    }

    /**
     * @dev uninstalls a validator to the account
     *
     * @param instance RhinestoneAccount
     * @param validator ERC7579 Module address
     * @param initData bytes encoded initialization data.
     *       This data will be passed to the validator onuninstall by the account
     */
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

    // executes installExecutor with initData:0
    function installExecutor(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        returns (bytes32 userOpHash)
    {
        return installExecutor(instance, executor, "");
    }

    /**
     * @dev installs an executor to the account
     *
     * @param instance RhinestoneAccount
     * @param executor ERC7579 Module address
     * @param initData bytes encoded initialization data.
     *       This data will be passed to the executor oninstall by the account
     */
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

    // executes uninstallExecutor with initData:0
    function uninstallExecutor(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        returns (bytes32 userOpHash)
    {
        return uninstallExecutor(instance, executor, "");
    }

    /**
     * @dev uninstalls an executor to the account
     *
     * @param instance RhinestoneAccount
     * @param executor ERC7579 Module address
     * @param initData bytes encoded initialization data.
     *       This data will be passed to the executor onUninstall by the account
     */
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

    // executes installHook with initData:0
    function installHook(
        RhinestoneAccount memory instance,
        address hook
    )
        internal
        returns (bytes32 userOpHash)
    {
        return installHook(instance, hook, "");
    }

    /**
     * @dev installs a Hook to the account
     *
     * @param instance RhinestoneAccount
     * @param hook ERC7579 Module address
     * @param initData bytes encoded initialization data.
     *       This data will be passed to the hook oninstall by the account
     */
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

    // calls uninstallHook with initData:0
    function uninstallHook(
        RhinestoneAccount memory instance,
        address hook
    )
        internal
        returns (bytes32 userOpHash)
    {
        return uninstallHook(instance, hook, "");
    }

    /**
     * @dev installs a Hook to the account
     *
     * @param instance RhinestoneAccount
     * @param hook ERC7579 Module address
     * @param initData bytes encoded initialization data.
     *       This data will be passed to the hook oninstall by the account
     */
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

    /**
     * @dev installs a Fallback to the account
     *
     * @param instance RhinestoneAccount
     * @param fallbackHandler ERC7579 Module address
     * @param initData bytes encoded initialization data.
     *       This data will be passed to the fallbackHandler oninstall by the account
     */
    function installFallback(
        RhinestoneAccount memory instance,
        address fallbackHandler,
        bytes memory initData
    )
        internal
        returns (bytes32 userOpHash)
    {
        UserOperation memory userOp = toUserOp({
            instance: instance,
            callData: instance.account.configModule(
                fallbackHandler,
                initData,
                ERC7579Helpers.installFallback // <--
            )
        });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });
    }

    /**
     * @dev Installs ExtensibleFallbackHandler on the account if not already installed, and
     * configures
     *
     * @param instance RhinestoneAccount
     * @param handleFunctionSig function sig that should be handled
     * @param isStatic is function staticcall or call
     * @param subHandler ExtensibleFallbackHandler subhandler to handle this function sig
     */
    function installFallback(
        RhinestoneAccount memory instance,
        bytes4 handleFunctionSig,
        bool isStatic,
        address subHandler
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
            // length: 2 (install of ExtensibleFallbackHandler + configuration of subhandler)
            executions = new IERC7579Execution.Execution[](2);

            //  get Execution struct to install ExtensibleFallbackHandler on account
            executions[0] = IERC7579Execution.Execution({
                target: instance.account,
                value: 0,
                callData: instance.account.configModule(
                    address(instance.aux.fallbackHandler), // ExtensibleFallbackHandler from Auxiliary
                    "",
                    ERC7579Helpers.installFallback // <--
                )
            });
        } else {
            // length: 1 (configuration of subhandler. ExtensibleFallbackHandler is already
            // installed as the FallbackHandler on the Account)
            executions = new IERC7579Execution.Execution[](1);
        }

        // Follow ExtensibleFallbackHandler ABI
        ExtensibleFallbackHandler.FallBackType fallbackType = isStatic
            ? ExtensibleFallbackHandler.FallBackType.Static
            : ExtensibleFallbackHandler.FallBackType.Dynamic;
        ExtensibleFallbackHandler.Params memory params = ExtensibleFallbackHandler.Params({
            selector: handleFunctionSig,
            fallbackType: fallbackType,
            handler: subHandler
        });

        // set the function selector on the ExtensibleFallbackHandler
        // using executions.length -1 here because we want this to be the last execution
        executions[executions.length - 1] = IERC7579Execution.Execution({
            target: address(instance.aux.fallbackHandler),
            value: 0,
            callData: abi.encodeCall(ExtensibleFallbackHandler.setFunctionSig, (params))
        });

        // form UserOp of batched Execution
        UserOperation memory userOp =
            toUserOp({ instance: instance, callData: executions.encode() });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });

        emit ModuleKitLogs.ModuleKit_SetFallback(instance.account, handleFunctionSig, subHandler);
    }

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
        returns (bytes32 userOpHash, bytes32 sessionKeyDigest)
    {
        IERC7579Execution.Execution[] memory executions;

        // detect if account was not created yet, or if SessionKeyManager is not installed
        if (
            instance.initCode.length > 0
                || !isValidatorInstalled(instance, address(instance.aux.sessionKeyManager))
        ) {
            executions = new IERC7579Execution.Execution[](2);
            // install core/SessionKeyManager first
            executions[0] = IERC7579Execution.Execution({
                target: instance.account,
                value: 0,
                callData: instance.account.configModule(
                    address(instance.aux.sessionKeyManager),
                    "",
                    ERC7579Helpers.installValidator // <--
                )
            });
        }

        // configure SessionKeyManager/SessionData according to params
        SessionData memory sessionData = SessionData({
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

        UserOperation memory userOp =
            toUserOp({ instance: instance, callData: executions.encode() });

        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });

        // get sessionKey digest
        sessionKeyDigest = instance.aux.sessionKeyManager.digest(sessionData);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Execute Transactions on the account
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Sign and execute a UserOperation
     * this uses the ERC7579Helpers.signUserOp function to sign the UserOperation
     * validator selection will be encoded in the UserOp nonce
     *
     * @param instance RhinestoneAccount
     * @param userOp UserOperation
     * @param validator address of ERC7579 validator module
     * @param signature bytes encoded signature
     */
    function signAndExec4337(
        RhinestoneAccount memory instance,
        UserOperation memory userOp,
        address validator,
        bytes memory signature
    )
        internal
        returns (bytes32 userOpHash)
    {
        (userOpHash, userOp) = ERC7579Helpers.signatureInNonce(
            instance.account, instance.aux.entrypoint, userOp, validator, signature
        );

        ERC4337Helpers.exec4337(instance.account, instance.aux.entrypoint, userOp);
    }

    // wrapper for signAndExec4337
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
        bytes memory singleExec = ERC7579Helpers.encode(target, value, callData);
        UserOperation memory userOp = toUserOp({ instance: instance, callData: singleExec });
        bytes1 MODE_USE = 0x00;
        bytes memory signature =
            abi.encodePacked(MODE_USE, abi.encode(sessionKeyDigest, sessionKeySignature));

        return signAndExec4337(instance, userOp, address(instance.aux.sessionKeyManager), signature);
    }

    // wrapper for signAndExec4337
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

        bytes memory batchedTx = ERC7579Helpers.toExecutions(targets, values, callDatas).encode();
        UserOperation memory userOp = toUserOp({ instance: instance, callData: batchedTx });

        return signAndExec4337(instance, userOp, address(instance.aux.sessionKeyManager), signature);
    }

    // wrapper for signAndExec4337
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

    // wrapper for signAndExec4337
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

    // wrapper for signAndExec4337
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

    // wrapper for signAndExec4337
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
        bytes memory singleExec = ERC7579Helpers.encode(target, value, callData);
        UserOperation memory userOp = toUserOp({ instance: instance, callData: singleExec });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: validator,
            signature: signature
        });
    }

    // wrapper for signAndExec4337
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

    // wrapper for signAndExec4337
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
        bytes memory batchedCallData =
            ERC7579Helpers.toExecutions(targets, values, callDatas).encode();
        UserOperation memory userOp = toUserOp({ instance: instance, callData: batchedCallData });
        userOpHash = signAndExec4337({
            instance: instance,
            userOp: userOp,
            validator: validator,
            signature: signature
        });
    }

    // wrapper for signAndExec4337
    function exec4337(
        RhinestoneAccount memory instance,
        IERC7579Execution.Execution[] memory executions
    )
        internal
        returns (bytes32 userOpHash)
    {
        return exec4337(instance, executions, address(instance.defaultValidator), "");
    }

    // wrapper for signAndExec4337
    function exec4337(
        RhinestoneAccount memory instance,
        IERC7579Execution.Execution[] memory executions,
        address validator,
        bytes memory signature
    )
        internal
        returns (bytes32 userOpHash)
    {
        bytes memory batchedCallData = executions.encode();
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
     * @dev Checks if hook is enabled
     *
     * @param instance RhinestoneAccount
     * @param hook Hook address
     *
     * @return isEnabled True if hook is enabled
     */
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
