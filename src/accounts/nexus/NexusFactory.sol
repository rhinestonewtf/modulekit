// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Interfaces
import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";
import { INexusAccountFactory } from "src/accounts/nexus/interfaces/INexusAccountFactory.sol";
import {
    INexusBootstrap,
    BootstrapConfig as NexusBootstrapConfig
} from "src/accounts/nexus/interfaces/INexusBootstrap.sol";

// Constants
import { ENTRYPOINT_ADDR } from "src/test/predeploy/EntryPoint.sol";

// Utils
import { NexusPrecompiles } from "src/test/precompiles/NexusPrecompiles.sol";

contract NexusFactory is IAccountFactory {
    INexusAccountFactory internal factory;
    INexusBootstrap internal bootstrapDefault;
    address internal nexusImpl;
    NexusPrecompiles internal precompiles;

    function init() public override {
        precompiles = new NexusPrecompiles();
        // Deploy precompiled contracts
        nexusImpl = precompiles.deployNexus(ENTRYPOINT_ADDR);
        factory = precompiles.deployNexusAccountFactory(nexusImpl, address(this));
        bootstrapDefault = precompiles.deployNexusBootstrap();
    }

    function createAccount(
        bytes32 salt,
        bytes memory initCode
    )
        public
        override
        returns (address account)
    {
        account = factory.createAccount(initCode, salt);
    }

    function getAddress(
        bytes32 salt,
        bytes memory initCode
    )
        public
        view
        override
        returns (address)
    {
        return factory.computeAccountAddress(initCode, salt);
    }

    function getInitData(
        address validator,
        bytes memory initData
    )
        public
        view
        override
        returns (bytes memory _init)
    {
        NexusBootstrapConfig memory config =
            NexusBootstrapConfig({ module: validator, data: initData });
        return bootstrapDefault.getInitNexusWithSingleValidatorCalldata(config);
    }
}
