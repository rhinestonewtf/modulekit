// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./dependencies/EntryPoint.sol";
import { IRhinestone4337, UserOperation } from "../../core/IRhinestone4337.sol";
import { ExecutorManager } from "../../core/ExecutorManager.sol";
import { IBootstrap } from "../../common/IBootstrap.sol";
import { Bootstrap } from "./safe-base/BootstrapSafe.sol";
import { IProtocolFactory } from "../../common/IRhinestoneProtocol.sol";
import { IERC7484Registry } from "../../common/IERC7484Registry.sol";
import { IValidator } from "../../modulekit/interfaces/IValidator.sol";

import { MockValidator } from "../mocks/MockValidator.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";
import { MockProtocol } from "../mocks/MockProtocol.sol";
import { MockCondition } from "../mocks/MockCondition.sol";
import { ComposableConditionManager } from "../../core/ComposableCondition.sol";

import { ChainlinkPriceCondition } from "../../modulekit/conditions/ChainlinkPriceCondition.sol";
import { GasPriceCondition } from "../../modulekit/conditions/GasPriceCondition.sol";
import { ScheduleCondition } from "../../modulekit/conditions/ScheduleCondition.sol";
import { SignatureCondition } from "../../modulekit/conditions/SignatureCondition.sol";

import "./Vm.sol";

struct Auxiliary {
    IEntryPoint entrypoint;
    IRhinestone4337 rhinestoneManager;
    ExecutorManager executorManager;
    ComposableConditionManager compConditionManager;
    IBootstrap rhinestoneBootstrap;
    IProtocolFactory rhinestoneFactory;
    IValidator validator;
    IERC7484Registry registry;
    address initialTrustedAttester;
    Conditions conditions;
}

struct Conditions {
    ChainlinkPriceCondition priceCondition;
    GasPriceCondition gasPriceCondition;
    ScheduleCondition scheduleCondition;
    SignatureCondition signatureCondition;
    MockCondition mockCondition;
}

contract AuxiliaryFactory {
    IEntryPoint internal entrypoint;

    MockValidator internal mockValidator;
    IERC7484Registry internal mockRegistry;
    MockProtocol internal mockRhinestoneFactory;
    ExecutorManager internal executorManager;
    ComposableConditionManager internal compConditionManager;

    Conditions internal conditions;

    Bootstrap internal bootstrap;

    address defaultAttester;

    function init() internal virtual {
        conditions = Conditions({
            priceCondition: new ChainlinkPriceCondition(),
            gasPriceCondition: new GasPriceCondition(),
            scheduleCondition: new ScheduleCondition(),
            signatureCondition: new SignatureCondition(),
            mockCondition: new MockCondition()
        });

        defaultAttester = address(0x4242424242);
        label(defaultAttester, "defaultAttester");
        bootstrap = new Bootstrap();
        label(address(bootstrap), "bootstrap");

        entrypoint = etchEntrypoint();
        label(address(entrypoint), "entrypoint");
        mockValidator = new MockValidator();
        label(address(mockValidator), "mockValidator");
        mockRegistry = IERC7484Registry(address(new MockRegistry()));
        label(address(mockRegistry), "mockRegistry");
        mockRhinestoneFactory = new MockProtocol();
        label(address(mockRhinestoneFactory), "mockRhinestoneFactory");

        compConditionManager = new ComposableConditionManager(mockRegistry);
        label(address(compConditionManager), "compConditionManager");
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
            compConditionManager: compConditionManager,
            rhinestoneBootstrap: _bootstrap,
            rhinestoneFactory: IProtocolFactory(address(mockRhinestoneFactory)),
            validator: mockValidator,
            registry: mockRegistry,
            initialTrustedAttester: defaultAttester,
            conditions: conditions
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
