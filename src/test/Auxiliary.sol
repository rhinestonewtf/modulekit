// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24 <0.9.0;

import { IEntryPoint, PackedUserOperation } from "../external/ERC4337.sol";
import { IERC7579Bootstrap } from "src/accounts/erc7579/interfaces/IERC7579Bootstrap.sol";
import { IERC7484 } from "src/Interfaces.sol";
import { etchEntrypoint } from "./predeploy/EntryPoint.sol";
import { etchSmartSessions } from "./precompiles/SmartSessions.sol";
import { EntryPointSimulations } from
    "@ERC4337/account-abstraction/contracts/core/EntryPointSimulations.sol";
import { IEntryPointSimulations } from
    "@ERC4337/account-abstraction/contracts/interfaces/IEntryPointSimulations.sol";
import { etchRegistry } from "./predeploy/Registry.sol";
import { MockFactory } from "./predeploy/MockFactory.sol";
import { UserOpGasLog } from "./utils/gas/UserOpGasLog.sol";
import { ISmartSession } from "src/test/helpers/interfaces/ISmartSession.sol";
import "./utils/Vm.sol";
import "./utils/Log.sol";

struct Auxiliary {
    IEntryPoint entrypoint;
    UserOpGasLog gasSimulation;
    IERC7484 registry;
    MockFactory mockFactory;
    ISmartSession smartSession;
}

contract AuxiliaryFactory {
    Auxiliary public auxiliary;

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
