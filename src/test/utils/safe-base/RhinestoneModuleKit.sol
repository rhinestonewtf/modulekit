// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SafeProxy } from "safe-contracts/contracts/proxies/SafeProxy.sol";
import { Safe } from "safe-contracts/contracts/Safe.sol";
import { SafeProxyFactory } from "safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import { ValidatorSelectionLib } from "../../../modulekit/lib/ValidatorSelectionLib.sol";
import { Merkle } from "murky/Merkle.sol";
import { ISafe } from "../../../common/ISafe.sol";
import { IERC7484Registry } from "../../../common/IERC7484Registry.sol";
import { RhinestoneSafeFlavor } from "./RhinestoneSafeFlavor.sol";
import { SafeExecutorManager } from "./SafeExecutorManager.sol";
import { ConditionConfig } from "../../../core/ComposableCondition.sol";
import {
    Auxiliary,
    IRhinestone4337,
    AuxiliaryFactory,
    Bootstrap,
    AuxiliaryLib,
    UserOperation
} from "../Auxiliary.sol";

import "../Vm.sol";

import "../../../common/FallbackHandler.sol";

import "../Log.sol";

import "forge-std/console2.sol";

struct RhinestoneAccount {
    address account;
    IRhinestone4337 rhinestoneManager;
    Auxiliary aux;
    bytes32 salt;
    AccountFlavor accountFlavor;
}

struct AccountFlavor {
    SafeProxyFactory accountFactory;
    ISafe accountSingleton;
}

contract RhinestoneModuleKit is AuxiliaryFactory {
    IRhinestone4337 internal rhinestoneManager;
    Bootstrap internal safeBootstrap;

    SafeProxyFactory internal safeFactory;
    Safe internal safeSingleton;

    bool initialzed;

    event InstanceCreated(address indexed account);

    function init() internal override {
        super.init();
        executorManager = new SafeExecutorManager(IERC7484Registry(address(mockRegistry)));
        label(address(executorManager), "ExecutorManager");
        safeFactory = new SafeProxyFactory();
        label(address(safeFactory), "SafeFactory");
        safeSingleton = new Safe();
        label(address(safeSingleton), "SafeSingleton");

        rhinestoneManager = IRhinestone4337(
            address(
                new RhinestoneSafeFlavor(
                address(entrypoint),
                mockRegistry
                )
            )
        );
        label(address(rhinestoneManager), "Rhinestone4337");
        safeBootstrap = new Bootstrap();
        label(address(safeBootstrap), "SafeBootstrap");
        initialzed = true;
    }

    function makeRhinestoneAccount(bytes32 salt)
        internal
        returns (RhinestoneAccount memory instance)
    {
        if (!initialzed) init();

        Auxiliary memory env = makeAuxiliary(address(rhinestoneManager), safeBootstrap);

        instance = RhinestoneAccount({
            account: getAccountAddress(env, salt),
            rhinestoneManager: rhinestoneManager,
            aux: env,
            salt: salt,
            accountFlavor: AccountFlavor({
                accountFactory: safeFactory,
                accountSingleton: ISafe(address(safeSingleton))
            })
        });

        emit InstanceCreated(instance.account);
    }

    function getAccountAddress(
        Auxiliary memory env,
        bytes32 _salt
    )
        public
        returns (address payable)
    {
        // Get initializer
        bytes memory initializer = SafeHelpers.getSafeInitializer(env, _salt);

        // Safe deployment data
        bytes memory deploymentData =
            abi.encodePacked(type(SafeProxy).creationCode, uint256(uint160(address(safeSingleton))));
        // Get salt
        // bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), _salt));
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(safeFactory), salt, keccak256(deploymentData))
        );
        return payable(address(uint160(uint256(hash))));
    }
}

import { SafeHelpers } from "./SafeSetup.sol";
import { ERC4337Wrappers } from "./ERC4337Helpers.sol";

library RhinestoneModuleKitLib {
    /*//////////////////////////////////////////////////////////////////////////
                                EXEC4337
    //////////////////////////////////////////////////////////////////////////*/

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        bytes memory callData
    )
        internal
    {
        exec4337(instance, target, 0, callData);
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
    {
        exec4337(instance, target, value, callData, 0, bytes(""));
    }

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
            ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, 0);

        if (signature.length == 0) {
            signature = bytes(hex"414141414141414141414141414141414141414141414141414141414141");
            signature = ValidatorSelectionLib.encodeValidator({
                signature: signature,
                chosenValidator: address(instance.aux.validator)
            });
        }
        exec4337(instance, data, signature);
    }

    /// @dev added method to allow for delegatecall operation
    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        uint8 operation, // {0: Call, 1: DelegateCall}
        bytes memory signature
    )
        internal
    {
        bytes memory data =
            ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, operation);

        if (signature.length == 0) {
            signature = bytes(hex"414141414141414141414141414141414141414141414141414141414141");
            signature = ValidatorSelectionLib.encodeValidator({
                signature: signature,
                chosenValidator: address(instance.aux.validator)
            });
        }
        exec4337(instance, data, signature);
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
            isDeployed(instance) ? bytes("") : SafeHelpers.safeInitCode(instance);
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(instance, callData, initCode);
        // mock signature
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
        emit ModuleKitLogs.ModuleKit_Exec4337(address(instance.account), userOp.sender);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODULES
    //////////////////////////////////////////////////////////////////////////*/

    function addValidator(RhinestoneAccount memory instance, address validator) internal {
        exec4337({
            instance: instance,
            target: address(instance.account),
            value: 0,
            callData: abi.encodeCall(instance.rhinestoneManager.addValidator, (validator))
        });
        emit ModuleKitLogs.ModuleKit_AddValidator(address(instance.account), validator);
    }

    function removeValidator(RhinestoneAccount memory instance, address validator) internal {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array, address next) =
            instance.rhinestoneManager.getValidatorPaginated(address(0x1), 100, instance.account);

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
            callData: abi.encodeWithSelector(
                instance.rhinestoneManager.removeValidator.selector, previous, validator
                )
        });
        emit ModuleKitLogs.ModuleKit_RemoveValidator(address(instance.account), validator);
    }

    function isValidatorEnabled(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        returns (bool isEnabled)
    {
        isEnabled = instance.rhinestoneManager.isValidatorEnabled(instance.account, validator);
    }

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
            !instance.rhinestoneManager.isValidatorEnabled(
                instance.account, address(instance.aux.sessionKeyManager)
            )
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

    function addHook(RhinestoneAccount memory instance, address hook) internal {
        exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeCall(instance.aux.executorManager.setHook, hook)
        });
    }

    function isHookEnabled(
        RhinestoneAccount memory instance,
        address hook
    )
        internal
        returns (bool isEnabled)
    {
        isEnabled = address(instance.aux.executorManager.enabledHooks(instance.account)) == hook;
    }

    function addExecutor(RhinestoneAccount memory instance, address executor) internal {
        exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeCall(instance.aux.executorManager.enableExecutor, (executor, false))
        });

        require(isExecutorEnabled(instance, executor), "Executor not enabled");
        emit ModuleKitLogs.ModuleKit_AddExecutor(address(instance.account), executor);
    }

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

        emit ModuleKitLogs.ModuleKit_RemoveExecutor(address(instance.account), executor);

        exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeCall(instance.aux.executorManager.disableExecutor, (previous, executor))
        });
    }

    function isExecutorEnabled(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        returns (bool isEnabled)
    {
        isEnabled =
            instance.aux.executorManager.isExecutorEnabled(address(instance.account), executor);
    }

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

    function addFallback(
        RhinestoneAccount memory instance,
        bytes4 handleFunctionSig,
        bool isStatic,
        address handler
    )
        internal
    {
        bytes32 encodedData = MarshalLib.encodeWithSelector(isStatic, handleFunctionSig, handler);
        exec4337({
            instance: instance,
            target: address(instance.account),
            value: 0,
            callData: abi.encodeWithSelector(
                instance.rhinestoneManager.setSafeMethod.selector, handleFunctionSig, encodedData
                )
        });
        emit ModuleKitLogs.ModuleKit_SetFallback(
            address(instance.account), handleFunctionSig, handler
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                UTILS
    //////////////////////////////////////////////////////////////////////////*/

    function getUserOpHash(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes32)
    {
        UserOperation memory userOp = getFormattedUserOp(instance, target, value, callData, 0);
        bytes32 userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);

        return userOpHash;
    }

    /// @dev added method to allow for delegatecall operation
    function getUserOpHash(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        uint8 operation // {0: Call, 1: DelegateCall}
    )
        internal
        returns (bytes32)
    {
        UserOperation memory userOp =
            getFormattedUserOp(instance, target, value, callData, operation);
        bytes32 userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);

        return userOpHash;
    }

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
            ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, 0);
        bytes memory initCode =
            isDeployed(instance) ? bytes("") : SafeHelpers.safeInitCode(instance);
        userOp = ERC4337Wrappers.getPartialUserOp(instance, data, initCode);
    }

    function getFormattedUserOp(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        uint8 operation // {0: Call, 1: DelegateCall}
    )
        internal
        returns (UserOperation memory userOp)
    {
        bytes memory data =
            ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, operation);
        bytes memory initCode =
            isDeployed(instance) ? bytes("") : SafeHelpers.safeInitCode(instance);
        userOp = ERC4337Wrappers.getPartialUserOp(instance, data, initCode);
    }

    function expect4337Revert(RhinestoneAccount memory) internal {
        writeExpectRevert(1);
    }

    function isDeployed(RhinestoneAccount memory instance) internal view returns (bool) {
        address _addr = address(instance.account);
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    event SDKLOG_RemoveExecutor(address account, address executor, address prevExecutor);
    event SDKLOG_RemoveValidator(address account, address executor, address prevExecutor);
}
