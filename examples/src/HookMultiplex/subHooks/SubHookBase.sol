// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISubHook } from "../ISubHook.sol";

abstract contract SubHookBase is ISubHook {
    address internal immutable MULTIPLEXER;

    error Unauthorized();

    constructor(address multiplexer) {
        MULTIPLEXER = multiplexer;
    }

    modifier onlyMultiplexer() {
        if (msg.sender != MULTIPLEXER) revert Unauthorized();
        _;
    }
}
