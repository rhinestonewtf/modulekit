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
import { INexus } from "./interfaces/INexus.sol";

// Constants
import { ENTRYPOINT_ADDR } from "../../deployment/predeploy/EntryPoint.sol";
import { REGISTRY_ADDR } from "../../deployment/predeploy/Registry.sol";

// Utils
import { NexusPrecompiles } from "../../deployment/precompiles/NexusPrecompiles.sol";

contract NexusFactory is IAccountFactory, NexusPrecompiles {
    INexusAccountFactory internal factory;
    INexusBootstrap internal bootstrapDefault;
    address internal nexusImpl;

    function init() public override {
        // Deploy precompiled contracts
        nexusImpl = deployNexus(ENTRYPOINT_ADDR);
        factory = deployNexusAccountFactory(nexusImpl, address(this));
        bootstrapDefault = deployNexusBootstrap();
    }

    function createAccount(
        bytes32 salt,
        bytes memory initCode
    )
        public
        override
        returns (address account)
    {
        return deployNexusProxy(salt, nexusImpl, initCode);
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
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(
                    abi.encodePacked(
                        NEXUS_PROXY_BYTECODE,
                        abi.encode(
                            address(nexusImpl), abi.encodeCall(INexus.initializeAccount, initCode)
                        )
                    )
                )
            )
        );

        return address(uint160(uint256(hash)));
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
