// SPDX-License-Identifier: MIT

import { Auxiliary, AuxiliaryLib } from "../Auxiliary.sol";
import { RhinestoneAccount } from "./RhinestoneModuleKit.sol";
import "safe-contracts/contracts/Safe.sol";
import { InitialModule } from "../../../contracts/auxiliary/interfaces/IBootstrap.sol";

import { IRhinestone4337 } from "../../../contracts/account/IRhinestone4337.sol";
import { IBootstrap } from "../../../contracts/auxiliary/interfaces/IBootstrap.sol";

pragma solidity ^0.8.19;

library SafeHelpers {
    function safeInitCode(RhinestoneAccount memory instance) internal returns (bytes memory) {
        return abi.encodePacked(
            instance.accountFlavor.accountFactory,
            abi.encodeWithSelector(
                instance.accountFlavor.accountFactory.createProxyWithNonce.selector,
                address(instance.accountFlavor.accountSingleton),
                getSafeInitializer(instance.aux, instance.salt),
                instance.salt
            )
        );
    }

    function getSafeInitializer(Auxiliary memory env, bytes32 salt) public returns (bytes memory) {
        // Initial owner of safe, removed by init4337Safe
        address safeOwner = address(0xdead);

        // Get proxy address of safe ERC4337 module

        address safe4337ModuleCloneAddress =
            AuxiliaryLib.getModuleCloneAddress(env, address(env.rhinestoneManager), salt);

        InitialModule[] memory modules = new InitialModule[](2);

        // Add ERC4337 module on Safe deployment
        modules[0] = InitialModule({
            moduleAddress: address(env.rhinestoneManager),
            salt: salt,
            initializer: abi.encodeWithSelector(
                IRhinestone4337.initialize.selector,
                address(0),
                env.validator,
                env.recovery,
                env.registry,
                address(0x696969696969),
                env.rhinestoneFactory
                ),
            requiresClone: true
        });

        modules[1] = InitialModule({
            moduleAddress: address(env.executorManager),
            salt: salt,
            initializer: "",
            requiresClone: false
        });

        // Calldata sent to init4337Safe
        bytes memory initModuleCalldata = abi.encodeWithSelector(
            IBootstrap.initialize.selector, modules, env.rhinestoneFactory, safeOwner
        );

        // Initial owners of Safe
        address[] memory owners = new address[](1);
        owners[0] = safeOwner;
        return abi.encodeWithSelector(
            Safe.setup.selector,
            owners, // owners
            1, // threshold
            address(env.rhinestoneBootstrap), // init module
            initModuleCalldata, // init module calldata
            safe4337ModuleCloneAddress, // fallbackHandler
            address(0), // payment token
            0, // payment
            address(0) // payment receiver
        );
    }
}
