// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IEntryPoint, PackedUserOperation } from "../external/ERC4337.sol";
import { ERC7579Bootstrap } from "../external/ERC7579.sol";
import { IERC7484Registry } from "../interfaces/IERC7484Registry.sol";
import { etchEntrypoint } from "./predeploy/EntryPoint.sol";
import { EntryPointSimulations } from
    "@ERC4337/account-abstraction/contracts/core/EntryPointSimulations.sol";
import { IEntryPointSimulations } from
    "@ERC4337/account-abstraction/contracts/interfaces/IEntryPointSimulations.sol";
import { ISessionKeyManager, etchSessionKeyManager } from "./predeploy/SessionKeyManager.sol";
import { ExtensibleFallbackHandler } from "../core/ExtensibleFallbackHandler.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";
import { MockFactory } from "./predeploy/MockFactory.sol";

/* solhint-disable no-global-import */
import "./utils/Vm.sol";
import "./utils/Log.sol";

struct Auxiliary {
    IEntryPoint entrypoint;
    UserOpGasLog gasSimulation;
    ISessionKeyManager sessionKeyManager;
    ExtensibleFallbackHandler fallbackHandler;
    ERC7579Bootstrap bootstrap;
    IERC7484Registry registry;
    address initialTrustedAttester;
    MockFactory mockFactory;
}

contract UserOpGasLog {
    EntryPointSimulations public immutable simulation = new EntryPointSimulations();

    struct GasLog {
        uint256 gasValidation;
        uint256 gasExecution;
    }

    mapping(bytes32 userOpHash => GasLog log) internal _log;

    function getLog(bytes32 userOpHash)
        external
        returns (uint256 gasValidation, uint256 gasExecution)
    {
        GasLog memory log = _log[userOpHash];
        return (log.gasValidation, log.gasExecution);
    }

    function calcValidationGas(
        PackedUserOperation memory userOp,
        bytes32 userOpHash,
        address sender,
        bytes memory initCode
    )
        external
        returns (uint256 gasValidation)
    {
        IEntryPointSimulations.ValidationResult memory validationResult =
            simulation.simulateValidation(userOp);

        gasValidation = validationResult.returnInfo.preOpGas;

        _log[userOpHash].gasValidation = gasValidation;
    }

    function calcExecutionGas(
        PackedUserOperation memory userOp,
        bytes32 userOpHash,
        address sender,
        bytes memory initCode
    )
        external
        returns (uint256 gasValidation, uint256 gasExecution)
    {
        IEntryPointSimulations.ExecutionResult memory executionResult =
            simulation.simulateHandleOp(userOp, sender, initCode);

        gasExecution = executionResult.paid;
        // gasValidation = executionResult.gasUsedInValidation;

        // _log[userOpHash].gasValidation = executionResult.gasUsedInValidation;
        _log[userOpHash].gasExecution = gasExecution;
    }
}

contract AuxiliaryFactory {
    Auxiliary public auxiliary;

    function init() internal virtual {
        auxiliary.mockFactory = new MockFactory();
        label(address(auxiliary.mockFactory), "Mock Factory");
        auxiliary.gasSimulation = new UserOpGasLog();
        auxiliary.entrypoint = etchEntrypoint();
        label(address(auxiliary.entrypoint), "EntryPoint");
        auxiliary.bootstrap = new ERC7579Bootstrap();
        label(address(auxiliary.bootstrap), "ERC7579Bootstrap");
        auxiliary.registry = new MockRegistry();
        label(address(auxiliary.registry), "ERC7484Registry");
        auxiliary.initialTrustedAttester = makeAddr("Trusted Attester");
        auxiliary.sessionKeyManager = etchSessionKeyManager();
        label(address(auxiliary.sessionKeyManager), "SessionKeyManager");
        auxiliary.fallbackHandler = new ExtensibleFallbackHandler();
        label(address(auxiliary.fallbackHandler), "FallbackHandler");
    }
}
