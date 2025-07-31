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
    INexusAccountFactory public factory;
    INexusBootstrap public bootstrapDefault;
    address public nexusImpl;

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

    function createAccountWithModules(
        bytes32 salt,
        NexusBootstrapConfig[] calldata validators,
        NexusBootstrapConfig[] calldata executors,
        NexusBootstrapConfig calldata hook,
        NexusBootstrapConfig[] calldata fallbacks
    )
        public
        payable
        virtual
        returns (address)
    {
        address[] memory attesters = new address[](1);
        attesters[0] = address(0x000000333034E9f539ce08819E12c1b8Cb29084d);

        bytes memory initData = abi.encode(
            bootstrapDefault,
            abi.encodeCall(
                INexusBootstrap.initNexus,
                (validators, executors, hook, fallbacks, IERC7484(REGISTRY_ADDR), attesters, 1)
            )
        );

        address account = deployNexusProxy(salt, nexusImpl, initData);

        return account;
    }

    function getInitData(
        IAccountFactory.ModuleInitData[] memory _validators,
        IAccountFactory.ModuleInitData[] memory _executors,
        IAccountFactory.ModuleInitData memory _hook,
        IAccountFactory.ModuleInitData[] memory _fallbacks
    )
        public
        view
        override
        returns (bytes memory _init)
    {
        NexusBootstrapConfig[] memory validators =
            abi.decode(abi.encode(_validators), (NexusBootstrapConfig[]));
        NexusBootstrapConfig[] memory executors =
            abi.decode(abi.encode(_executors), (NexusBootstrapConfig[]));
        NexusBootstrapConfig memory hook = abi.decode(abi.encode(_hook), (NexusBootstrapConfig));
        NexusBootstrapConfig[] memory fallbacks =
            abi.decode(abi.encode(_fallbacks), (NexusBootstrapConfig[]));

        address[] memory attesters = new address[](1);
        attesters[0] = address(0x000000333034E9f539ce08819E12c1b8Cb29084d);

        _init = abi.encode(
            address(bootstrapDefault),
            abi.encodeCall(
                INexusBootstrap.initNexus,
                (validators, executors, hook, fallbacks, IERC7484(REGISTRY_ADDR), attesters, 1)
            )
        );
    }

    function getInitData(bytes memory initData) public view returns (bytes memory _init) {
        (
            NexusBootstrapConfig[] memory validators,
            NexusBootstrapConfig[] memory executors,
            NexusBootstrapConfig memory hook,
            NexusBootstrapConfig[] memory fallbacks
        ) = abi.decode(
            initData,
            (
                NexusBootstrapConfig[],
                NexusBootstrapConfig[],
                NexusBootstrapConfig,
                NexusBootstrapConfig[]
            )
        );
        address[] memory attesters = new address[](1);
        attesters[0] = address(0x000000333034E9f539ce08819E12c1b8Cb29084d);

        _init = abi.encode(
            address(bootstrapDefault),
            abi.encodeCall(
                INexusBootstrap.initNexus,
                (validators, executors, hook, fallbacks, IERC7484(REGISTRY_ADDR), attesters, 1)
            )
        );
    }
}
