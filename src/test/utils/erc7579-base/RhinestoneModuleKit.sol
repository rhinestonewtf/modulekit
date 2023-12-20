// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {MSAHooks as MSA} from "erc7579/accountExamples/MSA_withHookExtension.sol";
import "erc7579/MSAFactory.sol";
import "./BootstrapUtil.sol";
import "erc7579/interfaces/IMSA.sol";
import {
    Auxiliary,
    IRhinestone4337,
    AuxiliaryFactory,
    AuxiliaryLib,
    UserOperation
} from "../Auxiliary.sol";
import "../Vm.sol";
import "../Log.sol";

import "./ERC4337Helpers.sol";

import "../../mocks/erc7579/MockValidator.sol";
import { SessionKeyManager } from "../../../core/SessionKeyManager.sol";
import { ConditionConfig } from "../../../core/ComposableCondition.sol";
import { IBootstrap } from "../../../common/IBootstrap.sol";

struct RhinestoneAccount {
    address account;
    address defaultValidator;
    Auxiliary aux;
    bytes32 salt;
}

contract RhinestoneModuleKit is AuxiliaryFactory, BootstrapUtil {
    Bootstrap public miniMSABootstrap;
    MSAFactory public msaFactory;
    MSA public msaImplementationSingleton;

    bool isInit;

    IExecutor public defaultExecutor;
    IValidator public defaultValidator;

    function init() internal virtual override {
        super.init();
        miniMSABootstrap = new Bootstrap();

        isInit = true;
        msaImplementationSingleton = new MSA();
        msaFactory = new MSAFactory(address(msaImplementationSingleton));

        defaultValidator = IValidator(address(new MockValidator()));
        sessionKeyManager = new SessionKeyManager(16,132);
    }

    function makeRhinestoneAccount(bytes32 salt)
        internal
        returns (RhinestoneAccount memory instance)
    {
        if (!isInit) init();
        Auxiliary memory env = makeAuxiliary(address(0), IBootstrap(address(0)), sessionKeyManager);

        BootstrapConfig[] memory validators =
            makeBootstrapConfig(address(defaultValidator), bytes(""));

        BootstrapConfig[] memory emptyConfig = new BootstrapConfig[](1);
        emptyConfig[0] = BootstrapConfig(IModule(address(0)), bytes(""));

        address account = msaFactory.createAccount({
            salt: salt,
            initCode: miniMSABootstrap._getInitMSACalldata(
                validators, emptyConfig, emptyConfig[0], emptyConfig[0]
                )
        });
        instance = RhinestoneAccount({
            account: account,
            aux: env,
            salt: salt,
            defaultValidator: address(defaultValidator)
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
        exec4337(instance, target, value, callData, signature, instance.defaultValidator);
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
    function addValidator(RhinestoneAccount memory instance, address validator, bytes memory initData) internal {
        exec4337(
            instance,
            instance.account,
            abi.encodeCall(IAccountConfig.installValidator, (validator, initData))
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
        return IMSA(instance.account).isValidatorEnabled(validator);
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
    function addHook(RhinestoneAccount memory instance, address hook, bytes memory initData) internal {


        exec4337(
            instance,
            instance.account,
            abi.encodeCall(IAccountConfig_Hook.installHook, (hook, initData))
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
        revert("Not supported yet");
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
            abi.encodeCall(IAccountConfig.installExecutor, (executor, ""))
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
        // TODO
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
        return IMSA(instance.account).isExecutorEnabled(executor);
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
            abi.encodeCall(IAccountConfig.installFallback, (handler, ""))
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
    { }

    /**
     * @dev Adds a condition to the Condition Manager
     *
     * @param instance RhinestoneAccount
     * @param forExecutor Executor address for which the condition is used
     * @param conditions Condition config
     */
    function setCondition(
        RhinestoneAccount memory instance,
        address forExecutor,
        ConditionConfig[] memory conditions
    )
        internal
    {
        exec4337({
            instance: instance,
            target: address(instance.aux.compConditionManager),
            value: 0,
            callData: abi.encodeCall(
                instance.aux.compConditionManager.setHash, (forExecutor, conditions)
                )
        });
        emit ModuleKitLogs.ModuleKit_SetCondition(address(instance.account), forExecutor);
    }
}
