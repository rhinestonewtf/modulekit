// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../etch/EntryPoint.sol";
import { IRhinestone4337, UserOperation } from "../../core/IRhinestone4337.sol";
import { ExecutorManager } from "../../core/ExecutorManager.sol";
import { IBootstrap } from "../../common/IBootstrap.sol";
import { Bootstrap } from "./safe-base/BoostrapSafe.sol";
import { IProtocolFactory } from "../../common/IRhinestoneProtocol.sol";
import { IERC7484Registry } from "../../common/IERC7484Registry.sol";
import { IValidatorModule } from "../../modulekit/IValidator.sol";

import { MockValidator } from "../mocks/MockValidator.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";
import { MockProtocol } from "../mocks/MockProtocol.sol";

struct Auxiliary {
    IEntryPoint entrypoint;
    IRhinestone4337 rhinestoneManager;
    ExecutorManager executorManager;
    IBootstrap rhinestoneBootstrap;
    IProtocolFactory rhinestoneFactory;
    IValidatorModule validator;
    IERC7484Registry registry;
}

contract AuxiliaryFactory {
    IEntryPoint internal entrypoint;

    MockValidator internal mockValidator;
    IERC7484Registry internal mockRegistry;
    MockProtocol internal mockRhinestoneFactory;
    ExecutorManager internal executorManager;

    Bootstrap internal bootstrap;

    address defaultAttester;

    function init() internal virtual {
        defaultAttester = address(0x4242424242);
        bootstrap = new Bootstrap();

        entrypoint = etchEntrypoint();
        mockValidator = new MockValidator();
        mockRegistry = IERC7484Registry(address(new MockRegistry()));
        mockRhinestoneFactory = new MockProtocol();
    }

    function makeAuxiliary(
        address _rhinestoneManager,
        IBootstrap _bootstrap
    )
        internal
        view
        returns (Auxiliary memory aux)
    {
        aux = Auxiliary({
            entrypoint: entrypoint,
            rhinestoneManager: IRhinestone4337(_rhinestoneManager),
            executorManager: executorManager,
            rhinestoneBootstrap: _bootstrap,
            rhinestoneFactory: IProtocolFactory(address(mockRhinestoneFactory)),
            validator: mockValidator,
            registry: mockRegistry
        });
    }
}

library AuxiliaryLib {
    function getModuleCloneAddress(
        Auxiliary memory env,
        address implementationToClone,
        bytes32 salt
    )
        internal
        view
        returns (address)
    {
        return env.rhinestoneFactory.getClone(implementationToClone, salt);
    }

    function deployModuleClone(
        Auxiliary memory env,
        address implementationToClone,
        bytes32 salt
    )
        internal
        returns (address)
    {
        return env.rhinestoneFactory.cloneExecutor(implementationToClone, salt);
    }
}
