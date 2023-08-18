// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct InitialModule {
    address moduleAddress;
    bytes32 salt;
    bytes initializer;
    bool requiresClone;
}

interface IBootstrap {
    function initialize(InitialModule[] calldata modules, bytes32 cloneSalt, address proxyFactory, address owner)
        external;
}
