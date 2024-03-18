// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { CallType } from "erc7579/lib/ModeLib.sol";

interface ISafe7579Init {
    struct ModuleInit {
        address module;
        bytes initData;
    }

    function initializeAccount(
        ModuleInit[] calldata validators,
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit[] calldata hooks
    )
        external
        payable;
}
