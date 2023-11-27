// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../dependencies/Biconomy.sol";
// import { ISmartAccountFactory, ISmartAccount } from "./utils/Interfaces.sol";

import {
    Auxiliary,
    IRhinestone4337,
    AuxiliaryFactory,
    Bootstrap,
    AuxiliaryLib,
    UserOperation
} from "../Auxiliary.sol";
import { SafeExecutorManager } from "../safe-base/SafeExecutorManager.sol";
// import { RhinestoneSafeFlavor } from "../../../contracts/safe/RhinestoneSafeFlavor.sol";

import { SessionKeyManager } from "../../../core/SessionKeyManager.sol";
import { ExecutorManager } from "../../../core/ExecutorManager.sol";
import "../safe-base/SafeExecutorManager.sol";
import "../safe-base/RhinestoneSafeFlavor.sol";
import "../../../core/ComposableCondition.sol";

import { BiconomyHelpers } from "./BiconomySetup.sol";
import { ERC4337Wrappers } from "./ERC4337Helpers.sol";
import { Merkle } from "murky/Merkle.sol";

import "../../../common/FallbackHandler.sol";

import { ECDSA } from "solady/utils/ECDSA.sol";
import "../Vm.sol";

import "../Log.sol";

struct Owner {
    address addr;
    uint256 key;
}

struct RhinestoneAccount {
    address account;
    Auxiliary aux;
    bytes32 salt;
    AccountFlavor accountFlavor;
    address initialAuthModule;
    Owner initialOwner;
    address fallbackHandler;
}

struct AccountFlavor {
    ISmartAccountFactory accountFactory;
    ISmartAccount accountSingleton;
}

contract RhinestoneModuleKit is AuxiliaryFactory {
    Bootstrap internal safeBootstrap;

    ISmartAccountFactory internal accountFactory;
    ISmartAccount internal accountSingleton;
    address initialAuthModule;

    FallbackHandler internal fallbackHandler;

    bool initialzed;

    function init() internal override {
        super.init();
        executorManager = new SafeExecutorManager(mockRegistry);
        label(address(executorManager), "ExecutorManager");
        accountSingleton = deployAccountSingleton(address(entrypoint));
        label(address(accountSingleton), "AccountSingleton");
        accountFactory = deployAccountFactory(address(accountSingleton));
        label(address(accountFactory), "AccountFactory");
        initialAuthModule = deployECDSA();
        label(initialAuthModule, "initial auth module");

        fallbackHandler = new FallbackHandler();
        label(address(fallbackHandler), "FallbackHandler");

        safeBootstrap = new Bootstrap();
        label(address(safeBootstrap), "SafeBootstrap");
        initialzed = true;
    }

    function makeRhinestoneAccount(bytes32 salt)
        internal
        returns (RhinestoneAccount memory instance)
    {
        if (!initialzed) init();
        sessionKeyManager = new SessionKeyManager(16,132);
        label(address(sessionKeyManager), "sessionKeyManager");

        Auxiliary memory env = makeAuxiliary(address(0), safeBootstrap, sessionKeyManager);

        uint256 initialOwnerKey = 1;
        address initialOwnerAddress = getAddr(uint256(initialOwnerKey));

        instance = RhinestoneAccount({
            account: getAccountAddress(initialOwnerAddress, salt),
            aux: env,
            salt: salt,
            accountFlavor: AccountFlavor({
                accountFactory: accountFactory,
                accountSingleton: ISmartAccount(address(accountSingleton))
            }),
            initialAuthModule: address(initialAuthModule),
            initialOwner: Owner({ addr: initialOwnerAddress, key: initialOwnerKey }),
            fallbackHandler: address(fallbackHandler)
        });
        label(instance.account, "rhinestone account");
        emit ModuleKitLogs.ModuleKit_NewAccount(instance.account, "Rhinestone-Biconomy");
    }

    function getAccountAddress(
        address initialOwnerAddress,
        bytes32 salt
    )
        public
        view
        returns (address payable)
    {
        address account = accountFactory.getAddressForCounterFactualAccount(
            initialAuthModule,
            abi.encodeWithSignature("initForSmartAccount(address)", initialOwnerAddress),
            uint256(salt)
        );
        return payable(account);
    }
}

library RhinestoneModuleKitLib {
    /*//////////////////////////////////////////////////////////////////////////
                                EXEC4337
    //////////////////////////////////////////////////////////////////////////*/

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
        bytes memory data =
            ERC4337Wrappers.getBiconomy4337TxCalldata(instance, target, value, callData);
        exec4337(instance, data, signature);
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
        bytes memory data =
            ERC4337Wrappers.getBiconomy4337TxCalldata(instance, target, value, callData);
        exec4337(instance, data, encodeValidator(instance, signature, validator));
    }

    function exec4337(
        RhinestoneAccount memory instance,
        bytes memory callData,
        bytes memory signature
    )
        internal
    {
        // prepare ERC4337 UserOperation
        bytes memory initCode =
            isDeployed(instance) ? bytes("") : BiconomyHelpers.accountInitCode(instance);
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(instance, callData, initCode);

        // create signature
        if (signature.length == 0) {
            bytes32 userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
            (uint8 v, bytes32 r, bytes32 s) =
                sign(instance.initialOwner.key, ECDSA.toEthSignedMessageHash(userOpHash));
            bytes memory _signature = abi.encodePacked(r, s, v);
            signature = abi.encode(_signature, instance.initialAuthModule);
        }
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

    /**
     * @dev Adds a validator to the account
     *
     * @param instance RhinestoneAccount
     * @param validator Validator address
     */
    function addValidator(RhinestoneAccount memory instance, address validator) internal {
        exec4337({
            instance: instance,
            target: address(instance.account),
            value: 0,
            callData: abi.encodeCall(ISmartAccount.enableModule, (validator))
        });
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
            ISmartAccount(instance.account).getModulesPaginated(address(0x1), 100);

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
            callData: abi.encodeWithSelector(ISmartAccount.disableModule.selector, previous, validator)
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
        isEnabled = ISmartAccount(instance.account).isModuleEnabled(validator);
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
        if (
            isDeployed(instance)
                && !isValidatorEnabled(instance, address(instance.aux.sessionKeyManager))
        ) {
            addValidator(instance, address(instance.aux.sessionKeyManager));
        }

        Merkle m = new Merkle();

        bytes32 leaf = instance.aux.sessionKeyManager._sessionMerkelLeaf({
            validUntil: validUntil,
            validAfter: validAfter,
            sessionValidationModule: sessionValidationModule,
            sessionKeyData: sessionKeyData
        });

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = leaf;
        leaves[1] = leaf;

        root = m.getRoot(leaves);
        proof = m.getProof(leaves, 1);

        exec4337(
            instance,
            address(instance.aux.sessionKeyManager),
            abi.encodeCall(instance.aux.sessionKeyManager.setMerkleRoot, (root))
        );
    }

    /**
     * @dev Adds a hook to the account
     *
     * @param instance RhinestoneAccount
     * @param hook Hook address
     */
    function addHook(RhinestoneAccount memory instance, address hook) internal {
        revert("Not supported yet");
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
        if (
            (
                isDeployed(instance)
                    && !ISmartAccount(instance.account).isModuleEnabled(
                        address(instance.aux.executorManager)
                    )
            ) || !isDeployed(instance)
        ) {
            exec4337({
                instance: instance,
                target: address(instance.account),
                value: 0,
                callData: abi.encodeCall(
                    ISmartAccount.enableModule, (address(instance.aux.executorManager))
                    )
            });
        }
        exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeCall(instance.aux.executorManager.enableExecutor, (executor, false))
        });

        require(isExecutorEnabled(instance, executor), "Executor not enabled");
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
            instance.aux.executorManager.getExecutorsPaginated(address(0x1), 100, instance.account);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == executor) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == executor) previous = array[i - 1];
            }
        }

        emit SDKLOG_RemoveExecutor(address(instance.account), executor, previous);

        exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeCall(instance.aux.executorManager.disableExecutor, (previous, executor))
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
        isEnabled = instance.aux.executorManager.isExecutorEnabled(instance.account, executor);
    }

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
        // check if account is deployed and if fallback handler is enabled
        address fallbackHandler;
        if (isDeployed(instance)) {
            fallbackHandler = ISmartAccount(instance.account).getFallbackHandler();
        }

        if (fallbackHandler != instance.fallbackHandler) {
            exec4337({
                instance: instance,
                target: address(instance.account),
                value: 0,
                callData: abi.encodeCall(ISmartAccount.setFallbackHandler, (instance.fallbackHandler))
            });
        }

        bytes32 encodedData = MarshalLib.encodeWithSelector(isStatic, handleFunctionSig, handler);
        exec4337({
            instance: instance,
            target: address(instance.account),
            value: 0,
            callData: abi.encodeCall(FallbackHandler.setSafeMethod, (handleFunctionSig, encodedData))
        });

        emit ModuleKitLogs.ModuleKit_SetFallback(instance.account, handleFunctionSig, handler);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                UTILS
    //////////////////////////////////////////////////////////////////////////*/

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
        bytes memory data =
            ERC4337Wrappers.getBiconomy4337TxCalldata(instance, target, value, callData);
        bytes memory initCode =
            isDeployed(instance) ? bytes("") : BiconomyHelpers.accountInitCode(instance);
        userOp = ERC4337Wrappers.getPartialUserOp(instance, data, initCode);
    }

    /**
     * @dev Encodes a signature with a chosen validator
     *
     * @param instance RhinestoneAccount
     * @param signature Signature
     * @param chosenValidator Chosen validator
     *
     * @return packedSignature Packed signature
     */
    function encodeValidator(
        RhinestoneAccount memory instance,
        bytes memory signature,
        address chosenValidator
    )
        internal
        pure
        returns (bytes memory packedSignature)
    {
        packedSignature = abi.encode(signature, chosenValidator);
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
     * @dev Checks if an account is deployed
     *
     * @param instance RhinestoneAccount
     *
     * @return isDeployed True if account is deployed
     */
    function isDeployed(RhinestoneAccount memory instance) internal view returns (bool) {
        address _addr = address(instance.account);
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    event SDKLOG_RemoveExecutor(address account, address executor, address prevExecutor);
}
