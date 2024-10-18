// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable max-line-length */
import "../utils/Vm.sol";

// Interfaces
import { ISmartSession } from "smartsessions/ISmartSession.sol";

// Contracts
import { SmartSession } from "smartsessions/SmartSession.sol";

address constant SMARTSESSION_ADDR = 0x0000000071727De22e5E9D8bAF0EDAc6F37da034;

function etchSmartSessions() returns (ISmartSession) {
    SmartSession _smartSession = new SmartSession();
    etch(address(SMARTSESSION_ADDR), address(_smartSession).code);
    return ISmartSession(address(_smartSession));
}
