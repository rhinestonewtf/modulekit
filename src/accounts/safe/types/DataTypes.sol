// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { IERC7484 } from "../interfaces/IERC7484.sol";
import { CallType } from "../lib/ModeLib.sol";

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
