// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IAccountFactory } from "../factory/interface/IAccountFactory.sol";
import { INexusAccountFactory } from "../nexus/interfaces/INexusAccountFactory.sol";
import {
    INexusBootstrap,
    BootstrapConfig as NexusBootstrapConfig
} from "../nexus/interfaces/INexusBootstrap.sol";
import { IERC7484 } from "../../Interfaces.sol";

// Constants
import { ENTRYPOINT_ADDR } from "../../deployment/predeploy/EntryPoint.sol";
import { REGISTRY_ADDR } from "../../deployment/predeploy/Registry.sol";

// Utils
import { NexusPrecompiles } from "../../deployment/precompiles/NexusPrecompiles.sol";

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
        // Note: signature in nexus account factory is below
        // function createAccount(bytes calldata initData, bytes32 salt) external payable override
        // returns (address payable)
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

        address[] memory attesters = new address[](1);
        attesters[0] = address(0x000000333034E9f539ce08819E12c1b8Cb29084d);

        return bootstrapDefault.getInitNexusWithSingleValidatorCalldata(
            config, IERC7484(REGISTRY_ADDR), attesters, 1
        );
    }
}
