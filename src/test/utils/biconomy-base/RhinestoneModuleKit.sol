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

import { ExecutorManager } from "../../../core/ExecutorManager.sol";
import "../safe-base/SafeExecutorManager.sol";
import "../safe-base/Rhinestone4337SafeFlavour.sol";
import "../../../core/ComposableCondition.sol";

import { BiconomyHelpers } from "./BiconomySetup.sol";
import { ERC4337Wrappers } from "./ERC4337Helpers.sol";

import "../../../common/FallbackHandler.sol";

import { ECDSA } from "solady/src/utils/ECDSA.sol";
import "../Vm.sol";

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

        accountSingleton = deployAccountSingleton(address(entrypoint));
        accountFactory = deployAccountFactory(address(accountSingleton));
        initialAuthModule = deployECDSA();

        fallbackHandler = new FallbackHandler();

        safeBootstrap = new Bootstrap();
        initialzed = true;
    }

    function makeRhinestoneAccount(bytes32 salt)
        internal
        returns (RhinestoneAccount memory instance)
    {
        if (!initialzed) init();

        Auxiliary memory env = makeAuxiliary(address(0), safeBootstrap);

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
        return exec4337(instance, target, value, callData, bytes(""));
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
            ERC4337Wrappers.getBiconomy4337TxCalldata(instance, target, value, callData);
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
        instance.aux.entrypoint.handleOps(userOps, payable(address(0x69)));
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
            callData: abi.encodeWithSelector(ISmartAccount.enableModule.selector, validator)
        });
        return success;
    }

    function addRecovery(
        RhinestoneAccount memory instance,
        address validator,
        address recovery
    )
        internal
        returns (bool)
    {
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.account),
            value: 0,
            callData: abi.encodeWithSelector(ISmartAccount.enableModule.selector, recovery)
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
        bool isExecutorEnabled = instance.accountFlavor.accountSingleton.isModuleEnabled(
            address(instance.aux.executorManager)
        );
        if (!isExecutorEnabled) {
            (bool success, bytes memory data) = exec4337({
                instance: instance,
                target: address(instance.account),
                value: 0,
                callData: abi.encodeWithSelector(
                    ISmartAccount.enableModule.selector, address(instance.aux.executorManager)
                    )
            });
        }
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeWithSelector(
                instance.aux.executorManager.enableExecutor.selector, executor, false
                )
        });

        require(
            instance.aux.executorManager.isExecutorEnabled(address(instance.account), executor),
            "Executor not enabled"
        );
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
        // check if fallback handler is enabled
        address fallbackHandler = ISmartAccount(instance.account).getFallbackHandler();

        if (fallbackHandler != instance.fallbackHandler) {
            (bool success, bytes memory data) = exec4337({
                instance: instance,
                target: address(instance.account),
                value: 0,
                callData: abi.encodeCall(ISmartAccount.setFallbackHandler, (instance.fallbackHandler))
            });
        }

        bytes32 encodedData = MarshalLib.encodeWithSelector(isStatic, handleFunctionSig, handler);
        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.account),
            value: 0,
            callData: abi.encodeCall(FallbackHandler.setSafeMethod, (handleFunctionSig, encodedData))
        });
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

        if (array.length == 1) previous = address(0x0);
        else previous = array[array.length - 2];

        emit SDKLOG_RemoveExecutor(address(instance.account), executor, previous);

        (bool success, bytes memory data) = exec4337({
            instance: instance,
            target: address(instance.aux.executorManager),
            value: 0,
            callData: abi.encodeWithSelector(
                instance.aux.executorManager.disableExecutor.selector, previous, executor
                )
        });
        return success;
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
            ERC4337Wrappers.getBiconomy4337TxCalldata(instance, target, value, callData);
        bytes memory initCode =
            isDeployed(instance) ? bytes("") : BiconomyHelpers.accountInitCode(instance);
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
}
