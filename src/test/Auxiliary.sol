// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IEntryPoint } from "../external/ERC4337.sol";
import { ERC7579Bootstrap } from "../external/ERC7579.sol";
import { IERC7484Registry } from "../interfaces/IERC7484Registry.sol";
import { EntryPointFactory } from "./predeploy/EntryPoint.sol";
import { ISessionKeyManager, etchSessionKeyManager } from "./predeploy/SessionKeyManager.sol";
import { ExtensibleFallbackHandler } from "../core/ExtensibleFallbackHandler.sol";
import { MockRegistry } from "../mocks/MockRegistry.sol";

/* solhint-disable no-global-import */
import "./utils/Vm.sol";
import "./utils/Log.sol";

struct Auxiliary {
    IEntryPoint entrypoint;
    ISessionKeyManager sessionKeyManager;
    ExtensibleFallbackHandler fallbackHandler;
    ERC7579Bootstrap bootstrap;
    IERC7484Registry registry;
    address initialTrustedAttester;
}

contract AuxiliaryFactory {
    Auxiliary public auxiliary;

    function init() internal virtual {
        EntryPointFactory entryPointFactory = new EntryPointFactory();
        auxiliary.entrypoint = entryPointFactory.etchEntrypoint();
        label(address(auxiliary.entrypoint), "EntryPoint");
        auxiliary.bootstrap = new ERC7579Bootstrap();
        label(address(auxiliary.bootstrap), "ERC7579BootStrap");
        auxiliary.registry = new MockRegistry();
        label(address(auxiliary.registry), "ERC7484Registry");
        auxiliary.initialTrustedAttester = makeAddr("Trusted Attester");
        auxiliary.sessionKeyManager = etchSessionKeyManager();
        label(address(auxiliary.sessionKeyManager), "SessionKeyManager");
        auxiliary.fallbackHandler = new ExtensibleFallbackHandler();
        label(address(auxiliary.fallbackHandler), "FallbackHandler");
    }
}
