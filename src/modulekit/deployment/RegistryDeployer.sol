// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    REGISTRY_ADDR,
    IRegistry,
    AttestationRecord,
    ModuleRecord,
    IResolver,
    ResolverRecord
} from "../../test/utils/dependencies/Registry.sol";

contract RegistryDeployer {
    IRegistry registry = IRegistry(REGISTRY_ADDR);
    bytes32 resolverUID = 0xb9b4999cbba6cde047b368adda06dbadc43fa3e6673c373ed46aac455ed4e521; // Default resolver

    // <---- DEPLOYMENT ---->

    function deployModule(
        bytes memory code,
        bytes memory deployParams,
        bytes32 salt,
        bytes memory data
    )
        public
        returns (address moduleAddr)
    {
        bytes32 _resolverUID = getResolver();
        moduleAddr = registry.deploy(code, deployParams, salt, data, _resolverUID);
    }

    function deployModuleCreate3(
        bytes memory code,
        bytes memory deployParams,
        bytes32 salt,
        bytes memory data
    )
        public
        returns (address moduleAddr)
    {
        bytes32 _resolverUID = getResolver();
        moduleAddr = registry.deployC3(code, deployParams, salt, data, _resolverUID);
    }

    function deployModuleViaFactory(
        address factory,
        bytes memory callOnFactory,
        bytes memory data
    )
        public
        returns (address moduleAddr)
    {
        bytes32 _resolverUID = getResolver();
        moduleAddr = registry.deployViaFactory(factory, callOnFactory, data, _resolverUID);
    }

    // <---- REGISTRY MANAGEMENT ---->

    function getResolver() public view returns (bytes32 _resolverUID) {
        _resolverUID = resolverUID;
        ResolverRecord memory resolver = registry.getResolver(resolverUID);
        if (address(resolver.resolver) == address(0)) {
            revert InvalidResolver();
        }
    }

    function registerResolver(address resolver) public returns (bytes32 _resolverUID) {
        _resolverUID = registry.registerResolver(IResolver(resolver));
    }

    function getModule(address moduleAddress) public view returns (ModuleRecord memory) {
        return registry.getModule(moduleAddress);
    }

    function setRegistry(address _registry) public {
        registry = IRegistry(_registry);
    }

    function setResolverUID(bytes32 _resolverUID) public {
        resolverUID = _resolverUID;
    }

    error InvalidResolver();
}
