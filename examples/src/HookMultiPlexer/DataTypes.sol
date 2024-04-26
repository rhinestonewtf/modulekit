// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

enum HookType {
    GLOBAL,
    DELEGATECALL,
    VALUE,
    SIG,
    TARGET_SIG
}

struct SigHookInit {
    bytes4 sig;
    address[] subHooks;
}

struct Config {
    address[] globalHooks;
    address[] delegatecallHooks;
    address[] valueHooks;
    bytes4[] sigs;
    mapping(bytes4 => address[]) sigHooks;
    bytes4[] targetSigs;
    mapping(bytes4 => address[]) targetSigHooks;
}
