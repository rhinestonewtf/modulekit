// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import { IERC7484 } from "./interfaces/IERC7484.sol";
import { CallType } from "./lib/ModeLib.sol";

struct FallbackHandler {
    address handler;
    CallType calltype;
}

enum HookType {
    GLOBAL,
    SIG
}

struct ModuleInit {
    address module;
    bytes initData;
}

struct RegistryInit {
    IERC7484 registry;
    address[] attesters;
    uint8 threshold;
}
