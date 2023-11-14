// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {
    Auxiliary,
    IRhinestone4337,
    AuxiliaryFactory,
    Bootstrap,
    AuxiliaryLib,
    UserOperation
} from "../Auxiliary.sol";

import {
    IKernel,
    IKernelFactory,
    deployAccountSingleton,
    deployAccountFactory
} from "../dependencies/Kernel.sol";

struct RhinestoneAccount {
    address account;
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

    function init() internal override {
        super.init();

        accountSingleton = deployAccountSingleton(address(entrypoint));
        kernelFactory = deployAccountFactory(address(0), address(entrypoint));

        AccountFlavor memory flavor =
            AccountFlavor({ accountSingleton: accountSingleton, accountFactory: kernelFactory });

        kernelFactory.createAccount(address(accountSingleton), "", 1);
    }

    function makeRhinestoneAccount(bytes32 salt) internal { }
}
