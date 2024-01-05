// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IEntryPoint } from "../external/ERC4337.sol";
import { ERC7579Bootstrap } from "../external/ERC7579.sol";
import { IERC7484Registry } from "../interfaces/IERC7484Registry.sol";
import { etchEntrypoint } from "./predeploy/EntryPoint.sol";
import { ISessionKeyManager, etchSessionKeyManager } from "./predeploy/SessionKeyManager.sol";

import "../mocks/MockRegistry.sol";

import "./utils/Vm.sol";
import "./utils/Log.sol";

struct Auxiliary {
    IEntryPoint entrypoint;
    ISessionKeyManager sessionKeyManager;
    ERC7579Bootstrap bootstrap;
    IERC7484Registry registry;
    address initialTrustedAttester;
}

contract AuxiliaryFactory {
    Auxiliary public auxiliary;

    function init() internal virtual {
        auxiliary.entrypoint = etchEntrypoint();
        label(address(auxiliary.entrypoint), "EntryPoint");
        auxiliary.bootstrap = new ERC7579Bootstrap();
        label(address(auxiliary.bootstrap), "ERC7579BootStrap");
        auxiliary.registry = new MockRegistry();
        label(address(auxiliary.registry), "ERC7484Registry");
        auxiliary.initialTrustedAttester = makeAddr("Trusted Attester");
        auxiliary.sessionKeyManager = etchSessionKeyManager();
        label(address(auxiliary.sessionKeyManager), "SessionKeyManager");
    }
}
