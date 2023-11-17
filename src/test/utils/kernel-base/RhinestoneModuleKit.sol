// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ERC4337Wrappers } from "./ERC4337Helpers.sol";

import {
    Auxiliary,
    IRhinestone4337,
    AuxiliaryFactory,
    Bootstrap,
    AuxiliaryLib,
    UserOperation
} from "../Auxiliary.sol";
import { IBootstrap } from "src/common/IBootstrap.sol";
import { KernelExecutorManager } from "src/test/utils/kernel-base/KernelExecutorManager.sol";
import { IExecutorManager } from "src/modulekit/interfaces/IExecutor.sol";

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
    function exec4337(
        RhinestoneAccount storage instance,
        bytes memory callData,
        bytes memory signature
    )
        internal
        returns (bool success, bytes memory)
    {
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(
            instance.account, instance.aux.entrypoint, callData, ""
        );
        userOp.signature = signature;
        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        instance.aux.entrypoint.handleOps(userOps, payable(address(0x69)));
    }
}
