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

import "./utils/ERC7579Helpers.sol";
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
}

contract RhinestoneModuleKit is AuxiliaryFactory, BootstrapUtil {
    ERC7579AccountFactory public accountFactory;
    ERC7579Account public accountImplementationSingleton;

    using ERC4337Helper for *;

    bool isInit;

    MockValidator public defaultValidator;

    function init() internal virtual override {
        super.init();

        isInit = true;
        accountImplementationSingleton = new ERC7579Account();
        label(address(accountImplementationSingleton), "ERC7579AccountImpl");
        accountFactory = new ERC7579AccountFactory(address(accountImplementationSingleton));
        label(address(accountFactory), "ERC7579AccountFactory");
        defaultValidator = new  MockValidator();
        label(address(defaultValidator), "DefaultValidator");
    }

    function makeRhinestoneAccount(bytes32 salt)
        internal
        returns (RhinestoneAccount memory instance)
    {
        if (!isInit) init();

        ERC7579BootstrapConfig[] memory validators =
            makeBootstrapConfig(address(defaultValidator), bytes(""));

        ERC7579BootstrapConfig[] memory emptyConfig = new ERC7579BootstrapConfig[](1);
        emptyConfig[0] = ERC7579BootstrapConfig(IERC7579Module(address(0)), bytes(""));

        address account = accountFactory.createAccount({
            salt: salt,
            initCode: auxiliary.bootstrap._getInitMSACalldata(
                validators, emptyConfig, emptyConfig[0], emptyConfig[0]
                )
        });
        label(address(account), "Account");
        instance = RhinestoneAccount({
            account: account,
            aux: auxiliary,
            salt: salt,
            defaultValidator: IERC7579Validator(address(defaultValidator))
        });
    }

    function foobar(
        RhinestoneAccount memory instance,
        UserOperation memory userOp
    )
        internal
        returns (UserOperation memory)
    {
        userOp.map(signOp);
    }

    function signOp(UserOperation memory userOp) internal pure returns (UserOperation memory) {
        return userOp;
    }
}

library ERC4337Helper {
    // function sign(
    //     RhinestoneAccount memory account,
    //     UserOperation memory userOp,
    //     bytes memory signature,
    //     address memory validator
    // )
    //     internal
    //     pure
    //     returns (bytes32 userOpHash, UserOperation memory signedOp)
    // {
    //     uint192 key = uint192(bytes24(bytes20(address(validator))));
    //     uint256 nonce = instance.aux.entrypoint.getNonce(address(instance.account), key);
    //
    //     userOp = getFormattedUserOp(instance, target, value, callData);
    //     userOp.nonce = nonce;
    //     userOp.signature = signature;
    //
    //     // send userOps to 4337 entrypoint
    //
    //     userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
    // }

    function exec4337(
        address account,
        IEntryPoint entrypoint,
        UserOperation[] memory userOps
    )
        internal
    {
        recordLogs();
        entrypoint.handleOps(userOps, payable(address(0x69)));

        VmSafe.Log[] memory logs = getRecordedLogs();

        for (uint256 i; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == 0x1c4fada7374c0a9ee8841fc38afe82932dc0f8e69012e927f061a8bae611a201
            ) {
                if (getExpectRevert() != 1) revert("UserOperation failed");
            }
        }

        writeExpectRevert(0);

        for (uint256 i; i < userOps.length; i++) {
            emit ModuleKitLogs.ModuleKit_Exec4337(account, userOps[i].sender);
        }
    }

    function exec4337(
        address account,
        IEntryPoint entrypoint,
        UserOperation memory userOp
    )
        internal
    {
        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;
        exec4337(account, entrypoint, userOps);
    }

    function map(
        UserOperation[] memory self,
        function(UserOperation memory) returns (UserOperation memory) f
    )
        internal
        returns (UserOperation[] memory)
    {
        UserOperation[] memory result = new UserOperation[](self.length);
        for (uint256 i; i < self.length; i++) {
            result[i] = f(self[i]);
        }
        return result;
    }

    function map(
        UserOperation memory self,
        function(UserOperation memory) internal  returns (UserOperation memory) fn
    )
        internal
        returns (UserOperation memory)
    {
        return fn(self);
    }

    function reduce(
        UserOperation[] memory self,
        function(UserOperation memory, UserOperation memory)  returns (UserOperation memory) f
    )
        internal
        returns (UserOperation memory r)
    {
        r = self[0];
        for (uint256 i = 1; i < self.length; i++) {
            r = f(r, self[i]);
        }
    }

    function array(UserOperation memory op) internal pure returns (UserOperation[] memory ops) {
        ops = new UserOperation[](1);
        ops[0] = op;
    }

    function array(
        UserOperation memory op1,
        UserOperation memory op2
    )
        internal
        pure
        returns (UserOperation[] memory ops)
    {
        ops = new UserOperation[](2);
        ops[0] = op1;
        ops[0] = op2;
    }
}

library RhinestoneModuleKitLib {
    using ERC4337Helper for *;
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
        UserOperation memory userOp = ERC7579Helpers.emptyUserOp({
            account: instance.account,
            callData: instance.account.configModule(
                validator,
                initData,
                ERC7579Helpers.installValidator // <--
            )
        });
        userOpHash = exec4337({
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
        UserOperation memory userOp = ERC7579Helpers.emptyUserOp({
            account: instance.account,
            callData: instance.account.configModule(
                validator,
                initData,
                ERC7579Helpers.uninstallValidator // <--
            )
        });
        userOpHash = exec4337({
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
        UserOperation memory userOp = ERC7579Helpers.emptyUserOp({
            account: instance.account,
            callData: instance.account.configModule(executor, initData, ERC7579Helpers.installExecutor) // <--
         });
        userOpHash = exec4337({
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
        UserOperation memory userOp = ERC7579Helpers.emptyUserOp({
            account: instance.account,
            callData: instance.account.configModule(
                executor,
                initData,
                ERC7579Helpers.uninstallExecutor // <--
            )
        });
        userOpHash = exec4337({
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
        UserOperation memory userOp = ERC7579Helpers.emptyUserOp({
            account: instance.account,
            callData: instance.account.configModule(
                hook,
                initData,
                ERC7579Helpers.installHook // <--
            )
        });
        userOpHash = exec4337({
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
        UserOperation memory userOp = ERC7579Helpers.emptyUserOp({
            account: instance.account,
            callData: instance.account.configModule(
                hook,
                initData,
                ERC7579Helpers.uninstallHook // <--
            )
        });
        userOpHash = exec4337({
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

        bool enabled = IERC7579Config(instance.account).isFallbackInstalled(handler);

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

        executions[executions.length - 1] = IERC7579Execution.Execution({
            target: address(instance.aux.fallbackHandler),
            value: 0,
            callData: abi.encodeCall(
                ExtensibleFallbackHandler.setFunctionSig, (handleFunctionSig, fallbackType, handler)
                )
        });

        UserOperation memory userOp = ERC7579Helpers.emptyUserOp({
            account: instance.account,
            callData: executions.encodeExecution()
        });
        userOpHash = exec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });

        emit ModuleKitLogs.ModuleKit_SetFallback(instance.account, handleFunctionSig, handler);
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
        (userOpHash, userOp) = ERC7579Helpers.signUserOp(
            instance.account, instance.aux.entrypoint, userOp, validator, signature
        );

        ERC4337Helper.exec4337(instance.account, instance.aux.entrypoint, userOp);
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
        UserOperation memory userOp =
            ERC7579Helpers.emptyUserOp({ account: instance.account, callData: singleExec });
        userOpHash = exec4337({
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
        IERC7579Execution.Execution[] memory executions =
            ERC7579Helpers.toExecutions(targets, values, callDatas);
        bytes memory batchedCallData = executions.encodeExecution();
        UserOperation memory userOp =
            ERC7579Helpers.emptyUserOp({ account: instance.account, callData: batchedCallData });
        userOpHash = exec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
        });
    }

    function exec4337(
        RhinestoneAccount memory instance,
        IERC7579Execution.Execution[] memory executions
    )
        internal
        returns (bytes32 userOpHash)
    {
        bytes memory batchedCallData = executions.encodeExecution();
        UserOperation memory userOp =
            ERC7579Helpers.emptyUserOp({ account: instance.account, callData: batchedCallData });
        userOpHash = exec4337({
            instance: instance,
            userOp: userOp,
            validator: address(instance.defaultValidator),
            signature: ""
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
}
