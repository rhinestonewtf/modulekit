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

import { UserOperation } from "../external/ERC4337.sol";
import { Auxiliary, AuxiliaryFactory } from "./Auxiliary.sol";
import "./utils/BootstrapUtil.sol";
import "./utils/Vm.sol";
import "./utils/Log.sol";

import { MockValidator } from "../Mocks.sol";

struct RhinestoneAccount {
    address account;
    IERC7579Validator defaultValidator;
    Auxiliary aux;
    bytes32 salt;
}

contract RhinestoneModuleKit is AuxiliaryFactory, BootstrapUtil {
    ERC7579AccountFactory public accountFactory;
    ERC7579Account public accountImplementationSingleton;

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
}

library RhinestoneModuleKitLib {
    /**
     * @dev Executes an ERC-4337 transaction
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param callData Calldata
     */
    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        bytes memory callData
    )
        internal
    {
        exec4337(instance, target, 0, callData);
    }

    /**
     * @dev Executes an ERC-4337 transaction
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param value Value
     * @param callData Calldata
     */
    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
    {
        exec4337(instance, target, value, callData, bytes(""));
    }

    /**
     * @dev Executes an ERC-4337 transaction
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param value Value
     * @param callData Calldata
     * @param signature Signature
     */
    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes memory signature
    )
        internal
    {
        exec4337(instance, target, value, callData, signature, address(instance.defaultValidator));
    }

    /**
     * @dev Executes an ERC-4337 transaction
     * @dev this is an internal function that assumes that calldata is already correctly formatted
     * @dev only use this function if you want to manually encode the calldata, otherwise use the functions above
     *
     * @param instance RhinestoneAccount
     * @param callData ENcoded callData
     * @param signature Signature
     */
    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes memory signature,
        address validator
    )
        internal
    {
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        uint256 nonce = instance.aux.entrypoint.getNonce(address(instance.account), key);

        UserOperation memory userOp = getFormattedUserOp(instance, target, value, callData);
        userOp.nonce = nonce;
        userOp.signature = signature;

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        // send userOps to 4337 entrypoint

        recordLogs();
        instance.aux.entrypoint.handleOps(userOps, payable(address(0x69)));

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

        emit ModuleKitLogs.ModuleKit_Exec4337(instance.account, userOp.sender);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODULES
    //////////////////////////////////////////////////////////////////////////*/

    function addValidator(RhinestoneAccount memory instance, address validator) internal {
        return addValidator(instance, validator, bytes(""));
    }
    /**
     * @dev Adds a validator to the account
     *
     * @param instance RhinestoneAccount
     * @param validator Validator address
     */

    function addValidator(
        RhinestoneAccount memory instance,
        address validator,
        bytes memory initData
    )
        internal
    {
        exec4337(
            instance,
            instance.account,
            abi.encodeCall(IERC7579Config.installValidator, (validator, initData))
        );

        emit ModuleKitLogs.ModuleKit_AddValidator(instance.account, validator);
    }

    /**
     * @dev Removes a validator from the account
     *
     * @param instance RhinestoneAccount
     * @param validator Validator address
     */
    function removeValidator(RhinestoneAccount memory instance, address validator) internal {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array, address next) =
            ERC7579Account(instance.account).getValidatorPaginated(address(0x1), 100);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == validator) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == validator) previous = array[i - 1];
            }
        }

        exec4337({
            instance: instance,
            target: address(instance.account),
            value: 0,
            callData: abi.encodeCall(
                IERC7579Config.uninstallValidator, (validator, abi.encode(previous, ""))
                )
        });

        emit ModuleKitLogs.ModuleKit_RemoveValidator(address(instance.account), validator);
    }

    /**
     * @dev Checks if a validator is enabled
     *
     * @param instance RhinestoneAccount
     * @param validator Validator address
     *
     * @return isEnabled True if validator is enabled
     */
    function isValidatorEnabled(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        returns (bool isEnabled)
    {
        return IERC7579Config(instance.account).isValidatorInstalled(validator);
    }

    /**
     * @dev Adds a hook to the account
     *
     * @param instance RhinestoneAccount
     * @param hook Hook address
     */
    function addHook(RhinestoneAccount memory instance, address hook) internal {
        return addHook(instance, hook, bytes(""));
    }

    /**
     * @dev Adds a hook to the account
     *
     * @param instance RhinestoneAccount
     * @param hook Hook address
     */
    function addHook(
        RhinestoneAccount memory instance,
        address hook,
        bytes memory initData
    )
        internal
    {
        exec4337(
            instance,
            instance.account,
            abi.encodeCall(IERC7579ConfigHook.installHook, (hook, initData))
        );
    }

    /**
     * @dev Checks if a hook is enabled
     *
     * @param instance RhinestoneAccount
     * @param hook Hook address
     *
     * @return isEnabled True if hook is enabled
     */
    function isHookEnabled(
        RhinestoneAccount memory instance,
        address hook
    )
        internal
        returns (bool isEnabled)
    {
        return IERC7579ConfigHook(instance.account).isHookInstalled(hook);
    }

    /**
     * @dev Adds an executor to the account
     *
     * @param instance RhinestoneAccount
     * @param executor Executor address
     */
    function addExecutor(RhinestoneAccount memory instance, address executor) internal {
        exec4337(
            instance,
            instance.account,
            abi.encodeCall(IERC7579Config.installExecutor, (executor, ""))
        );

        emit ModuleKitLogs.ModuleKit_AddExecutor(instance.account, executor);
    }

    /**
     * @dev Removes an executor from the account
     *
     * @param instance RhinestoneAccount
     * @param executor Executor address
     */
    function removeExecutor(RhinestoneAccount memory instance, address executor) internal {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array,) =
            ERC7579Account(instance.account).getExecutorsPaginated(address(0x1), 100);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == executor) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == executor) previous = array[i - 1];
            }
        }

        exec4337({
            instance: instance,
            target: instance.account,
            value: 0,
            callData: abi.encodeCall(
                IERC7579Config.uninstallExecutor, (executor, abi.encode(previous, ""))
                )
        });

        emit ModuleKitLogs.ModuleKit_RemoveExecutor(instance.account, executor);
    }

    /**
     * @dev Checks if an executor is enabled
     *
     * @param instance RhinestoneAccount
     * @param executor Executor address
     *
     * @return isEnabled True if executor is enabled
     */
    function isExecutorEnabled(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        returns (bool isEnabled)
    {
        return IERC7579Config(instance.account).isExecutorInstalled(executor);
    }

    /**
     * @dev Adds a fallback handler to the account
     *
     * @param instance RhinestoneAccount
     * @param handleFunctionSig Function signature
     * @param isStatic True if function is static
     * @param handler Handler address
     */
    function addFallback(
        RhinestoneAccount memory instance,
        bytes4 handleFunctionSig,
        bool isStatic,
        address handler
    )
        internal
    {
        exec4337(
            instance,
            instance.account,
            abi.encodeCall(IERC7579Config.installFallback, (handler, ""))
        );
        emit ModuleKitLogs.ModuleKit_SetFallback(instance.account, handleFunctionSig, handler);
    }

    /**
     * @dev Gets the user operation hash
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param callData Calldata
     *
     * @return userOpHash User operation hash
     */
    function getUserOpHash(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes32)
    {
        UserOperation memory userOp = getFormattedUserOp(instance, target, value, callData);
        bytes32 userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
        return userOpHash;
    }

    /**
     * @dev Gets the formatted UserOperation
     *
     * @param instance RhinestoneAccount
     * @param target Target address
     * @param value Value to send
     * @param callData Calldata
     *
     * @return userOp Formatted UserOperation
     */
    function getFormattedUserOp(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (UserOperation memory userOp)
    {
        bytes memory erc7579Exec =
            ERC4337Wrappers.getERC7579TxCalldata(instance, target, value, callData);

        // Get account address
        address smartAccount = address(instance.account);

        // Get nonce from Entrypoint
        uint256 nonce = instance.aux.entrypoint.getNonce(smartAccount, 0);

        userOp = UserOperation({
            sender: smartAccount,
            nonce: nonce,
            initCode: "", // todo
            callData: erc7579Exec,
            callGasLimit: 2e6,
            verificationGasLimit: 2e6,
            preVerificationGas: 2e6,
            maxFeePerGas: 1,
            maxPriorityFeePerGas: 1,
            paymasterAndData: bytes(""),
            signature: bytes("")
        });
    }

    /**
     * @dev Expects an ERC-4337 transaction to revert
     * @dev if this is called before an exec4337 call, it will throw an error if the ERC-4337 flow does not revert
     *
     * @param instance RhinestoneAccount
     */
    function expect4337Revert(RhinestoneAccount memory instance) internal {
        writeExpectRevert(1);
    }

    /**
     * @dev Adds a session key to the account
     *
     * @param instance RhinestoneAccount
     * @param validUntil Valid until timestamp
     * @param validAfter Valid after timestamp
     * @param sessionValidationModule Session validation module address
     * @param sessionKeyData Session key data
     *
     * @return root Merkle root of session key manager
     * @return proof Merkle proof for session key
     */
    function addSessionKey(
        RhinestoneAccount memory instance,
        uint256 validUntil,
        uint256 validAfter,
        address sessionValidationModule,
        bytes memory sessionKeyData
    )
        internal
        returns (bytes32 root, bytes32[] memory proof)
    {
        revert("not implemented");
    }

    // /**
    //  * @dev Adds a condition to the Condition Manager
    //  *
    //  * @param instance RhinestoneAccount
    //  * @param forExecutor Executor address for which the condition is used
    //  * @param conditions Condition config
    //  */
    // function setCondition(
    //     RhinestoneAccount memory instance,
    //     address forExecutor,
    //     ConditionConfig[] memory conditions
    // )
    //     internal
    // {
    //     exec4337({
    //         instance: instance,
    //         target: address(instance.aux.compConditionManager),
    //         value: 0,
    //         callData: abi.encodeCall(
    //             instance.aux.compConditionManager.setHash, (forExecutor, conditions)
    //             )
    //     });
    //     emit ModuleKitLogs.ModuleKit_SetCondition(address(instance.account), forExecutor);
    // }
}

library ERC4337Wrappers {
    function getERC7579TxCalldata(
        RhinestoneAccount memory account,
        address target,
        uint256 value,
        bytes memory data
    )
        internal
        view
        returns (bytes memory erc7579Tx)
    {
        return abi.encodeCall(IERC7579Execution.execute, (target, value, data));
    }
}
