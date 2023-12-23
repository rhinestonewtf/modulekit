// SPDX-License-Identifier: MIT

import { Auxiliary, AuxiliaryLib } from "../Auxiliary.sol";
import { RhinestoneAccount } from "./RhinestoneModuleKit.sol";
import "safe-contracts/contracts/Safe.sol";
import { IBootstrap, InitialModule } from "../../../common/IBootstrap.sol";

import { IRhinestone4337 } from "../../../core/IRhinestone4337.sol";

pragma solidity ^0.8.19;

library SafeHelpers {
    function safeInitCode(RhinestoneAccount memory instance) internal pure returns (bytes memory) {
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

    function getSafeInitializer(
        Auxiliary memory env,
        bytes32 salt
    )
        public
        pure
        returns (bytes memory)
    {
        // Initial owner of safe, removed by init4337Safe
        address safeOwner = address(0xdead);
        address rhinestoneManagerAddress = address(env.rhinestoneManager);

        InitialModule[] memory modules = new InitialModule[](2);

        // Add ERC4337 module on Safe deployment
        modules[0] = InitialModule({
            moduleAddress: rhinestoneManagerAddress,
            salt: salt,
            initializer: abi.encodeCall(
                IRhinestone4337.init, (address(env.validator), env.initialTrustedAttester, bytes(""))
                ),
            requiresClone: false
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
            rhinestoneManagerAddress, // fallbackHandler
            address(0), // payment token
            0, // payment
            address(0) // payment receiver
        );
    }
}
