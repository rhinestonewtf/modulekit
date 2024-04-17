// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7484 } from "./IERC7484.sol";

interface ISafe7579Init {
    struct ModuleInit {
        address module;
        bytes initData;
    }

    struct RegistryInit {
        IERC7484 registry;
        address[] attesters;
        uint8 threshold;
    }

    function initializeAccount(
        ModuleInit[] calldata validators,
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit[] calldata hooks,
        RegistryInit calldata registryInit
    )
        external
        payable;

    function launchpadValidators(ModuleInit[] calldata validators) external payable;
}
