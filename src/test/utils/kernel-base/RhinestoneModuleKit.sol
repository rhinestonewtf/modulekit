// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ERC4337Wrappers } from "./ERC4337Helpers.sol";
import "src/test/utils/kernel-base/IKernel.sol";

import {
    Auxiliary,
    IRhinestone4337,
    AuxiliaryFactory,
    Bootstrap,
    AuxiliaryLib,
    UserOperation
} from "../Auxiliary.sol";
import { ConditionConfig } from "../../../core/ComposableCondition.sol";
import { IBootstrap } from "src/common/IBootstrap.sol";
import { KernelExecutorManager } from "src/test/utils/kernel-base/KernelExecutorManager.sol";
import { IExecutorManager } from "src/modulekit/interfaces/IExecutor.sol";

import { ValidatorSelectionLib } from "src/modulekit/lib/ValidatorSelectionLib.sol";

import {
    IKernel,
    IKernelFactory,
    deployAccountSingleton,
    deployAccountFactory
} from "../dependencies/Kernel.sol";

import "../Vm.sol";

struct RhinestoneAccount {
    address account;
    IExecutorManager executorManager;
    Auxiliary aux;
    bytes32 salt;
    AccountFlavor accountFlavor;
}

struct AccountFlavor {
    IKernel accountSingleton;
    IKernelFactory accountFactory;
}

contract RhinestoneModuleKit is AuxiliaryFactory {
    IKernelFactory kernelFactory;
    IKernel accountSingleton;
    bool initialzed;

    function init() internal override {
        super.init();

        accountSingleton = deployAccountSingleton(address(entrypoint));
        kernelFactory = deployAccountFactory(address(this), address(entrypoint));

        kernelFactory.setImplementation(address(accountSingleton), true);
        label(address(accountSingleton), "accountSingleton");

        initialzed = true;
    }

    function makeRhinestoneAccount(bytes32 salt)
        internal
        returns (RhinestoneAccount memory instance)
    {
        if (!initialzed) init();
        Auxiliary memory env = makeAuxiliary(address(0), IBootstrap(address(0)), sessionKeyManager);

        instance = RhinestoneAccount({
            account: kernelFactory.createAccount(address(accountSingleton), "", uint256(salt)),
            executorManager: IExecutorManager(address(new KernelExecutorManager(env.registry))),
            aux: env,
            salt: salt,
            accountFlavor: AccountFlavor({
                accountSingleton: accountSingleton,
                accountFactory: kernelFactory
            })
        });
        label(instance.account, "account instance");
    }

    function getAccountAddress(bytes memory data, bytes32 salt) internal view returns (address) {
        return IKernelFactory(kernelFactory).getAccountAddress(data, uint256(salt));
    }
}

library RhinestoneModuleKitLib {
    function encodeSig(bytes memory sig) internal pure returns (bytes memory) {
        bytes4 mode = 0;
        return abi.encodePacked(mode, sig);
    }

    function exec4337(
        RhinestoneAccount storage instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes memory signature,
        address validator
    )
        internal
    {
        bytes memory callData4337Exec =
            ERC4337Wrappers.getKernel4337TxCalldata(target, value, callData);
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(
            instance.account, instance.aux.entrypoint, callData, ""
        );
        userOp.signature = encodeSig(ValidatorSelectionLib.encodeValidator(signature, validator));
        userOp.callData = callData4337Exec;
        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        instance.aux.entrypoint.handleOps(userOps, payable(address(0x69)));
    }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        bytes memory signature
    )
        internal
    { }

    function exec4337(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
    { }

    function setCondition(
        RhinestoneAccount memory instance,
        address forExecutor,
        ConditionConfig[] memory conditions
    )
        internal
    { }

    function addSessionKey(
        RhinestoneAccount memory instance,
        uint256 validUntil,
        uint256 validAfter,
        address sessionValidationModule,
        bytes memory sessionKeyData
    )
        internal
    { }

    function setDefaultValidator(RhinestoneAccount memory instance) internal {
        // get default validator from kernel
        address currentDefaultValidator = IKernel(instance.account).getDefaultValidator();

        // if default validator is not set to instance.executorManager, set it
        if (currentDefaultValidator != address(instance.executorManager)) {
            IKernel(instance.account).setDefaultValidator(
                IKernelValidator(address(instance.executorManager)), ""
            );
        }
    }

    function addValidator(RhinestoneAccount memory instance, address validator) internal {
        setDefaultValidator(instance);
        // add validator to instance.executorManager
        KernelExecutorManager(address(instance.executorManager)).addValidator(validator);
    }

    function removeValidator(RhinestoneAccount memory instance, address validator) internal {
        setDefaultValidator(instance);
    }

    function addExecutor(RhinestoneAccount memory instance, address executor) internal {
        setDefaultValidator(instance);
        KernelExecutorManager(address(instance.executorManager)).enableExecutor(executor, false);
    }

    function removeExecutor(RhinestoneAccount memory instance, address executor) internal {
        setDefaultValidator(instance);
        address previous;
        KernelExecutorManager(address(instance.executorManager)).disableExecutor(previous, executor);
    }

    function addFallback(
        RhinestoneAccount memory instance,
        bytes4 handleFunctionSig,
        bool isStatic,
        address handler
    )
        internal
    { }

    function getUserOpHash(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes32)
    { }

    function isDeployed(RhinestoneAccount memory instance) internal view returns (bool) {
        address _addr = address(instance.account);
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
