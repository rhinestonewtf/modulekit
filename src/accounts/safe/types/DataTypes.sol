// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IERC7484 } from "../interfaces/IERC7484.sol";

// Types
import { CallType } from "../../common/lib/ModeLib.sol";

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
