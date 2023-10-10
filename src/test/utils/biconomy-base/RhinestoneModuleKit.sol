// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    SMART_ACCOUNT_BYTECODE,
    SMART_ACCOUNT_FACTORY_BYTECODE,
    ECDSA_OWNERSHIP_REGISTRY_MODULE_BYTECODE
} from "../../etch/Biconomy.sol";
import { ISmartAccountFactory, ISmartAccount } from "./utils/Interfaces.sol";

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

import { ECDSA } from "solady/src/utils/ECDSA.sol";

import "forge-std/Vm.sol";
import "forge-std/console.sol";

address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

function getAddr(uint256 pk) pure returns (address) {
    return Vm(VM_ADDR).addr(pk);
}

function sign(uint256 pk, bytes32 msgHash) pure returns (uint8 v, bytes32 r, bytes32 s) {
    return Vm(VM_ADDR).sign(pk, msgHash);
}

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

    bool initialzed;

    function init() internal override {
        super.init();
        executorManager = new SafeExecutorManager(mockRegistry);

        bytes memory accountSingletonArgs = abi.encode(entrypoint);
        bytes memory accountSingletonBytecode =
            abi.encodePacked(SMART_ACCOUNT_BYTECODE, accountSingletonArgs);
        address _accountSingleton;
        assembly {
            _accountSingleton :=
                create(0, add(accountSingletonBytecode, 0x20), mload(accountSingletonBytecode))
        }
        accountSingleton = ISmartAccount(_accountSingleton);

        bytes memory factoryArgs = abi.encode(_accountSingleton, address(0x69));
        bytes memory factoryBytecode = abi.encodePacked(SMART_ACCOUNT_FACTORY_BYTECODE, factoryArgs);
        address _accountFactory;
        assembly {
            _accountFactory := create(0, add(factoryBytecode, 0x20), mload(factoryBytecode))
        }
        accountFactory = ISmartAccountFactory(_accountFactory);

        bytes memory initialAuthModuleBytecode =
            abi.encodePacked(ECDSA_OWNERSHIP_REGISTRY_MODULE_BYTECODE);
        address _initialAuthModule;
        assembly {
            _initialAuthModule :=
                create(0, add(initialAuthModuleBytecode, 0x20), mload(initialAuthModuleBytecode))
        }
        initialAuthModule = _initialAuthModule;

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
            initialOwner: Owner({ addr: initialOwnerAddress, key: initialOwnerKey })
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
        bytes memory initCode =
            isDeployed(instance) ? bytes("") : BiconomyHelpers.accountInitCode(instance);
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

    event SDKLOG_RemoveExecutor(address account, address executor, address prevExecutor);
}
