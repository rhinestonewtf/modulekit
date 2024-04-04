// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ISafe7579Init {
    struct ModuleInit {
        address module;
        bytes initData;
    }

    function initializeAccount(ModuleInit[] calldata validators) external payable;
}
