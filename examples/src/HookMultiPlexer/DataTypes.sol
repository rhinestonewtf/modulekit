// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";

struct AllContext {
    PreCheckContext[] globalHooks;
    PreCheckContext[] valueHooks;
    PreCheckContext[] sigHooks;
    PreCheckContext[][] targetSigHooks;
}

struct SigHookInit {
    bytes4 sig;
    address[] subHooks;
}

struct PreCheckContext {
    address subHook;
    bytes context;
}

struct Config {
    address[] globalHooks;
    address[] valueHooks;
    mapping(bytes4 => address[]) sigHooks;
    bool targetSigHooksEnabled;
    mapping(bytes4 => address[]) targetSigHooks;
}
