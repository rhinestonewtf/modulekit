// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {EntryPoint} from "@aa/core/EntryPoint.sol";
import "../../../src/account/IRhinestone4337.sol";
import "../../src/auxiliary/interfaces/IBootstrap.sol";
import "../../src/auxiliary/interfaces/IProtocolFactory.sol";
import "../../src/auxiliary/interfaces/IRegistry.sol";

struct Auxiliary {
    EntryPoint entrypoint;
    IRhinestone4337 rhinestoneManager;
    IBootstrap rhinestoneBootstrap;
    IProtocolFactory rhinestoneFactory;
    IValidatorModule validator;
    IRecoveryModule recovery;
    IRegistry registry;
}

contract AuxiliaryFactory {
    EntryPoint internal entrypoint;

    MockValidator internal mockValidator;
    MockRecovery internal mockRecovery;
    MockRegistry internal mockRegistry;
    MockProtocol internal mockRhinestoneFactory;

    address defaultAttester;

    function init() internal virtual {
        defaultAttester = makeAddr("defaultAttester");
        bootstrap = new Bootstrap();

        entrypoint = new EntryPoint();
        mockValidator = new MockValidator();
        mockRecovery = new MockRecovery();
        mockRegistry = new MockRegistry();
        mockCloneFactory = new MockProtocol();
    }

    function makeAuxiliary(IRhinestone4337 _rhinestoneManger, IBootstrap _bootstrap)
        internal
        returns (Auxiliary memory aux)
    {
        aux = Auxiliary({
            entrypoint: entrypoint,
            rhinestoneManager: _rhinestoneManger,
            rhinestoneBootstrap: _bootstrap,
            rhinestoneFactory: rhinestoneFactory,
            validator: mockValidator,
            recovery: mockRecovery,
            registry: mockRegistry
        });
    }
}

library AuxiliaryLib {
    function getModuleCloneAddress(Auxiliary memory env, address implementationToClone, bytes32 salt)
        internal
        view
        returns (address)
    {
        MockProtocol factory = env.rhinestoneProtocol;

        return factory.getClone(implementationToClone, salt);
    }

    function deployModuleClone(Auxiliary memory env, address implementationToClone, bytes32 salt)
        internal
        returns (address)
    {
        MockProtocol factory = env.rhinestoneProtocol;
        return factory.clonePlugin(implementationToClone, salt);
    }
}
