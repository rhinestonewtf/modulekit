// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";
import { SENTINEL, SentinelListLib } from "sentinellist/SentinelList.sol";

enum SubHookType {
    GLOBAL,
    VALUE,
    SIGHOOK,
    TARGETSIGHOOK
}

struct AllContext {
    PreCheckContext[] globalHooks;
    PreCheckContext[] valueHooks;
    PreCheckContext[] sigHooks;
    PreCheckContext[][] targetSigHooks;
}

struct SigHookInit {
    bytes4 sig;
    IERC7579Hook[] subHooks;
}

struct PreCheckContext {
    IERC7579Hook subHook;
    bytes context;
}

struct Config {
    IERC7579Hook[] globalHooks;
    IERC7579Hook[] valueHooks;
    mapping(bytes4 => IERC7579Hook[]) sigHooks;
    mapping(bytes4 => IERC7579Hook[]) targetSigHooks;
}
// mapping(address target => IERC7579Hook[]) targetAddrHooks;
