// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EntryPoint} from "@aa/core/EntryPoint.sol";
import {SafeProxyFactory} from "safe-contracts/contracts/proxies/SafeProxyFactory.sol";

import "../../src/interfaces/ISafe.sol";
import "../../src/interfaces/IRhinestone4337.sol";

struct AccountInstance {
    address account;
    IRhinestone4337 rhinestoneManager;
    Auxiliary aux;
    bytes32 salt;
}

struct Auxiliary {
    EntryPoint entrypoint;
    IRhinestone4337 rhinestoneManager;
    IBootstrap rhinestoneBootstrap;
    IProtocol rhinestoneProtocol;
    IValidator validator;
    IRecovery recovery;
    IRegistry registry;
    AccountFlavour accountFlavour;
}

struct AccountFlavour {
    SafeProxyFactory accountFactory;
    ISafe accountSingleton;
}
