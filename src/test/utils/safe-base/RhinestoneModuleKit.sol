// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SafeProxy } from "safe-contracts/contracts/proxies/SafeProxy.sol";
import { Safe } from "safe-contracts/contracts/Safe.sol";
import { SafeProxyFactory } from "safe-contracts/contracts/proxies/SafeProxyFactory.sol";

import { Merkle } from "murky/Merkle.sol";
import { ISafe } from "../../../common/ISafe.sol";
import { IERC7484Registry } from "../../../common/IERC7484Registry.sol";
import { RhinestoneSafeFlavor } from "./Rhinestone4337SafeFlavor.sol";
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
        label(address(executorManager), "executorManager");
        safeFactory = new SafeProxyFactory();
        label(address(safeFactory), "safeFactory");
        safeSingleton = new Safe();
        label(address(safeSingleton), "safeSingleton");

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
        label(address(safeBootstrap), "safeBootstrap");
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
    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        bytes memory callData
    )
        internal
        returns (bool, bytes memory)
    {
        return exec4337(instance, target, 0, callData);
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bool, bytes memory)
    {
        return exec4337(instance, target, value, callData, 0, bytes(""));
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes memory signature
    )
        internal
        returns (bool, bytes memory)
    {
        bytes memory data =
            ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, 0);

        if (signature.length == 0) {
            // TODO: generate default signature
            signature = bytes("");
        }
        return exec4337(instance, data, signature);
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
        returns (bool, bytes memory)
    {
        bytes memory data =
            ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, operation);

        if (signature.length == 0) {
            // TODO: generate default signature
            signature = bytes("");
        }
        return exec4337(instance, data, signature);
    }

    function exec4337(
        RhinestoneAccount memory instance,
        bytes memory callData,
        bytes memory signature
    )
        internal
        returns (bool, bytes memory)
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
        instance.aux.entrypoint.handleOps(userOps, payable(address(0x69)));

        emit ModuleKitLogs.ModuleKit_Exec4337(address(instance.account), userOp.sender);
    }

    function setCondition(
        RhinestoneAccount memory instance,
        address forExecutor,
        ConditionConfig[] memory conditions
    )
        internal
        returns (bool)
    {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.aux.compConditionManager),
            value: 0,
            callData: abi.encodeCall(
                instance.aux.compConditionManager.setHash, (forExecutor, conditions)
                )
        });
        emit ModuleKitLogs.ModuleKit_SetCondition(address(instance.account), forExecutor);
        return success;
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
        leaves[0] = "asdf";
        leaves[1] = leaf;

        root = m.getRoot(leaves);
        proof = m.getProof(leaves, 1);

        exec4337(
            instance,
            address(instance.aux.sessionKeyManager),
            abi.encodeCall(instance.aux.sessionKeyManager.setMerkleRoot, (root))
        );
    }

    function addValidator(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        returns (bool)
    {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.account),
            value: 0,
            callData: abi.encodeCall(instance.rhinestoneManager.addValidator, (validator))
        });
        emit ModuleKitLogs.ModuleKit_AddValidator(address(instance.account), validator);
        return success;
    }

    function removeValidator(
        RhinestoneAccount memory instance,
        address validator
    )
        internal
        returns (bool)
    {
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

        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.account),
            value: 0,
            callData: abi.encodeWithSelector(
                instance.rhinestoneManager.removeValidator.selector, previous, validator
                )
        });
        emit ModuleKitLogs.ModuleKit_RemoveValidator(address(instance.account), validator);
        return success;
    }

    function addHook(RhinestoneAccount memory instance, address hook) internal returns (bool) {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeCall(instance.aux.executorManager.setHook, hook)
        });

        return success;
    }

    function addExecutor(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        returns (bool)
    {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeCall(instance.aux.executorManager.enableExecutor, (executor, false))
        });

        require(
            instance.aux.executorManager.isExecutorEnabled(address(instance.account), executor),
            "Executor not enabled"
        );
        emit ModuleKitLogs.ModuleKit_AddExecutor(address(instance.account), executor);
        return success;
    }

    function removeExecutor(
        RhinestoneAccount memory instance,
        address executor
    )
        internal
        returns (bool)
    {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array, address next) =
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

        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeCall(instance.aux.executorManager.disableExecutor, (previous, executor))
        });
        return success;
    }

    function addFallback(
        RhinestoneAccount memory instance,
        bytes4 handleFunctionSig,
        bool isStatic,
        address handler
    )
        internal
        returns (bool)
    {
        bytes32 encodedData = MarshalLib.encodeWithSelector(isStatic, handleFunctionSig, handler);
        (bool success, bytes memory data) = exec4337({
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

    function getUserOpHash(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes32)
    {
        bytes memory data =
            ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, 0);
        bytes memory initCode =
            isDeployed(instance) ? bytes("") : SafeHelpers.safeInitCode(instance);
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(instance, data, initCode);
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
        bytes memory data =
            ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, operation);
        bytes memory initCode =
            isDeployed(instance) ? bytes("") : SafeHelpers.safeInitCode(instance);
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(instance, data, initCode);
        bytes32 userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);

        return userOpHash;
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
