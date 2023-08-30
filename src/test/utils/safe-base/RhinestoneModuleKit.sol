// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "safe-contracts/contracts/proxies/SafeProxy.sol";
import "safe-contracts/contracts/Safe.sol";
import "safe-contracts/contracts/proxies/SafeProxyFactory.sol";

import "../Auxiliary.sol";
import "../../../contracts/safe/ISafe.sol";
import {SafeExecutorManager} from "../../../contracts/safe/SafeExecutorManager.sol";
import "../../../contracts/safe/RhinestoneSafeFlavor.sol";

import {SentinelListHelper} from "sentinellist/src/SentinelListHelper.sol";

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
    RhinestoneSafeFlavor internal rhinestoneManager;
    Bootstrap internal safeBootstrap;

    SafeProxyFactory internal safeFactory;
    Safe internal safeSingleton;

    bool initialzed;

    function init() internal override {
        super.init();
        executorManager = new SafeExecutorManager(address(mockRegistry));
        safeFactory = new SafeProxyFactory();
        safeSingleton = new Safe();

        rhinestoneManager = new RhinestoneSafeFlavor(
            address(entrypoint),
            address(mockRegistry),
            defaultAttester
        );

        safeBootstrap = new Bootstrap();
        initialzed = true;
    }

    function makeRhinestoneAccount(bytes32 salt) internal returns (RhinestoneAccount memory instance) {
        if (!initialzed) init();

        Auxiliary memory env = makeAuxiliary(rhinestoneManager, safeBootstrap);

        instance = RhinestoneAccount({
            account: getAccountAddress(env, salt),
            rhinestoneManager: IRhinestone4337(
                payable(AuxiliaryLib.getModuleCloneAddress(env, address(rhinestoneManager), salt))
                ),
            aux: env,
            salt: salt,
            accountFlavor: AccountFlavor({accountFactory: safeFactory, accountSingleton: ISafe(address(safeSingleton))})
        });
    }

    function getAccountAddress(Auxiliary memory env, bytes32 _salt) public returns (address payable) {
        // Get initializer
        bytes memory initializer = SafeHelpers.getSafeInitializer(env, _salt);

        // Safe deployment data
        bytes memory deploymentData =
            abi.encodePacked(type(SafeProxy).creationCode, uint256(uint160(address(safeSingleton))));
        // Get salt
        // bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), _salt));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(safeFactory), salt, keccak256(deploymentData)));
        return payable(address(uint160(uint256(hash))));
    }
}

import {SafeHelpers} from "./SafeSetup.sol";
import {ERC4337Wrappers} from "./ERC4337Helpers.sol";
import {IModuleManager} from "../../../contracts/modules/executors/IExecutorBase.sol";

library RhinestoneModuleKitLib {
    function exec4337(RhinestoneAccount memory instance, address target, bytes memory callData)
        internal
        returns (bool, bytes memory)
    {
        return exec4337(instance, target, 0, callData);
    }

    function exec4337(RhinestoneAccount memory instance, address target, uint256 value, bytes memory callData)
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
        uint8 operation, // {0: Call, 1: DelegateCall}
        bytes memory signature
    ) internal returns (bool, bytes memory) {
        bytes memory data = ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, operation);

        if (signature.length == 0) {
            // TODO: generate default signature
            signature = bytes("");
        }
        return exec4337(instance, data);
    }

    function exec4337(RhinestoneAccount memory instance, bytes memory callData) internal returns (bool, bytes memory) {
        // prepare ERC4337 UserOperation

        bytes memory initCode = isDeployed(instance) ? bytes("") : SafeHelpers.safeInitCode(instance);
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(instance, callData, initCode);
        // mock signature
        userOp.signature = bytes("");

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        // send userOps to 4337 entrypoint
        instance.aux.entrypoint.handleOps(userOps, payable(address(0x69)));
    }

    function callViaManager(RhinestoneAccount memory instance, address target, bytes memory callData)
        internal
        returns (bool, bytes memory)
    {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.rhinestoneManager),
            value: 0,
            callData: abi.encodeWithSelector(instance.rhinestoneManager.forwardCall.selector, target, callData)
        });
    }

    function addValidator(RhinestoneAccount memory instance, address validator) internal returns (bool) {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.rhinestoneManager),
            value: 0,
            callData: abi.encodeWithSelector(instance.rhinestoneManager.addValidator.selector, validator)
        });
        require(instance.rhinestoneManager.isEnabledValidator(validator), "INTERNAL ERROR: valdiator should be enabled");
        return success;
    }

    function removeValidator(RhinestoneAccount memory instance, address validator) internal returns (bool) {
        (address[] memory array, address next) = instance.rhinestoneManager.getValidatorsPaginated(address(0x1), 100);

        address previous = SentinelListHelper.findPrevious(array, validator);

        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.rhinestoneManager),
            value: 0,
            callData: abi.encodeWithSelector(instance.rhinestoneManager.removeValidator.selector, validator, previous)
        });
        require(
            !instance.rhinestoneManager.isEnabledValidator(validator), "INTERNAL ERROR: valdiator should be disabled"
        );
        return success;
    }

    function addRecovery(RhinestoneAccount memory instance, address validator, address recovery)
        internal
        returns (bool)
    {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.rhinestoneManager),
            value: 0,
            callData: abi.encodeWithSelector(instance.rhinestoneManager.addRecovery.selector, validator, recovery)
        });
        return success;
    }

    function removeRecovery(RhinestoneAccount memory instance, address validator) internal returns (bool) {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.rhinestoneManager),
            value: 0,
            callData: abi.encodeWithSelector(instance.rhinestoneManager.removeRecovery.selector, validator)
        });
        return success;
    }

    function addExecutor(RhinestoneAccount memory instance, address executor) internal returns (bool) {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeWithSelector(instance.aux.executorManager.enableExecutor.selector, executor, false)
        });

        require(
            instance.aux.executorManager.isExecutorEnabled(address(instance.account), executor), "Executor not enabled"
        );
        return success;
    }

    function removeExecutor(RhinestoneAccount memory instance, address executor) internal returns (bool) {
        (address[] memory array, address next) =
            instance.aux.executorManager.getExecutorsPaginated(address(0x1), 100, instance.account);

        address previous = SentinelListHelper.findPrevious(array, executor);

        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeWithSelector(instance.aux.executorManager.disableExecutor.selector, previous, executor)
        });

        require(
            !instance.aux.executorManager.isExecutorEnabled(instance.account, executor),
            "INTERAL ERROR: Removing Executor"
        );
        return success;
    }

    function getUserOpHash(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        uint8 operation // {0: Call, 1: DelegateCall}
    ) internal returns (bytes32) {
        bytes memory data = ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, operation);
        bytes memory initCode = isDeployed(instance) ? bytes("") : SafeHelpers.safeInitCode(instance);
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(instance, callData, initCode);
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
}
