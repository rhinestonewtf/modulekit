// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IEntryPoint, PackedUserOperation } from "../external/ERC4337.sol";
import { IERC7579Bootstrap } from "../accounts/erc7579/interfaces/IERC7579Bootstrap.sol";
import { IERC7484 } from "../Interfaces.sol";
import { ISmartSession } from "../integrations/interfaces/ISmartSession.sol";

// Deployments
import { etchEntrypoint } from "../deployment/predeploy/EntryPoint.sol";
import { etchSmartSessions } from "../deployment/precompiles/SmartSessionsPrecompiles.sol";
import { etchRegistry } from "../deployment/predeploy/Registry.sol";

// External Dependencies
import { EntryPointSimulations } from
    "@ERC4337/account-abstraction/contracts/core/EntryPointSimulations.sol";
import { IEntryPointSimulations } from
    "@ERC4337/account-abstraction/contracts/interfaces/IEntryPointSimulations.sol";

// Mocks
import { MockFactory } from "../deployment/predeploy/MockFactory.sol";

// Utils
import { UserOpGasLog } from "./utils/gas/UserOpGasLog.sol";
import "./utils/Vm.sol";
import "./utils/Log.sol";

/// @notice Auxiliary structs to hold all the necessary auxiliary contracts for testing.
/// @param entrypoint The entrypoint contract.
/// @param gasSimulation The gas simulation contract.
/// @param registry The registry contract.
/// @param mockFactory The mock factory contract.
/// @param smartSession The smart session contract.
struct Auxiliary {
    IEntryPoint entrypoint;
    UserOpGasLog gasSimulation;
    IERC7484 registry;
    MockFactory mockFactory;
    ISmartSession smartSession;
}

/// @notice Auxiliary factory to deploy all the necessary auxiliary contracts for testing.
contract AuxiliaryFactory {
    /// @notice Stores the auxiliary contracts.
    Auxiliary public auxiliary;

    /// @notice Initializes and labels all the auxiliary contracts.
    function init() internal virtual {
        auxiliary.mockFactory = new MockFactory();
        label(address(auxiliary.mockFactory), "Mock Factory");
        auxiliary.gasSimulation = new UserOpGasLog();
        auxiliary.entrypoint = etchEntrypoint();
        label(address(auxiliary.entrypoint), "EntryPoint");
        auxiliary.registry = etchRegistry();
        label(address(auxiliary.registry), "ERC7484Registry");
        auxiliary.smartSession = etchSmartSessions();
        label(address(auxiliary.smartSession), "SmartSession");
    }
}
