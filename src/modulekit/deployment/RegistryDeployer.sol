// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    REGISTRY_ADDR,
    IRegistry,
    AttestationRecord,
    ModuleRecord,
    IResolver,
    ResolverBase,
    DebugResolver,
    ResolverRecord
} from "../../test/utils/dependencies/Registry.sol";

contract RegistryDeployer {
    IRegistry registry = IRegistry(REGISTRY_ADDR);
    bytes32 resolverUID = 0x984f176bc8a8b71d1a35736c5a892be396a01ba80b290a3394d0089b891dcf46;
    address debugResolver = 0x9C49430a0f240B45f7f0ecc0AcF434E11C5878FF;

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

    function getResolver() public returns (bytes32 _resolverUID) {
        _resolverUID = resolverUID;
        ResolverRecord memory resolver = registry.getResolver(resolverUID);
        if (resolver.schemaOwner == address(0)) {
            _resolverUID = registerResolver(address(0));
            resolverUID = _resolverUID;
        }
    }

    function registerResolver(address resolver) public returns (bytes32) {
        if (resolver == address(0)) {
            bytes32 _debugResolverCode;
            assembly {
                _debugResolverCode := extcodehash(sload(debugResolver.slot))
            }
            if (_debugResolverCode == bytes32(0)) {
                DebugResolver newDebugResolver = new DebugResolver{salt:0}(address(registry));
                debugResolver = address(newDebugResolver);
            }
            return registry.registerResolver(IResolver(address(debugResolver)));
        } else {
            return registry.registerResolver(IResolver(resolver));
        }
    }

    function getModule(address moduleAddress) public view returns (ModuleRecord memory) {
        return registry.getModule(moduleAddress);
    }

    function setRegistry(address _registry) public {
        registry = IRegistry(_registry);
    }
}
