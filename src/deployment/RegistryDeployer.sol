// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IRegistry, IExternalResolver } from "registry/IRegistry.sol";
import { ResolverRecord, ModuleRecord, ResolverUID } from "registry/DataTypes.sol";

address constant REGISTRY_ADDR = 0xe0cde9239d16bEf05e62Bbf7aA93e420f464c826;

contract RegistryDeployer {
    IRegistry internal registry = IRegistry(REGISTRY_ADDR);

    // Default resolver
    ResolverUID internal resolverUID =
        ResolverUID.wrap(0xdf658e5595d93baa803af242dc6e175b4cbef04de73509b50b944d1b2d167bb6);

    error InvalidResolver();

    // <---- DEPLOYMENT ---->

    function deployModule(
        bytes memory initCode,
        bytes32 salt,
        bytes memory metadata,
        bytes memory resolverContext
    )
        public
        returns (address moduleAddr)
    {
        ResolverUID _resolverUID = findResolver();
        moduleAddr = registry.deployModule({
            resolverUID: _resolverUID,
            initCode: initCode,
            salt: salt,
            metadata: metadata,
            resolverContext: resolverContext
        });
    }

    function deployModuleViaFactory(
        address factory,
        bytes memory callOnFactory,
        bytes memory metadata,
        bytes memory resolverContext
    )
        public
        returns (address moduleAddr)
    {
        ResolverUID _resolverUID = findResolver();
        moduleAddr = registry.deployViaFactory({
            factory: factory,
            callOnFactory: callOnFactory,
            metadata: metadata,
            resolverUID: _resolverUID,
            resolverContext: resolverContext
        });
    }

    // <---- REGISTRY MANAGEMENT ---->

    function findResolver() public view returns (ResolverUID _resolverUID) {
        _resolverUID = resolverUID;
        ResolverRecord memory resolver = registry.findResolver(resolverUID);
        if (address(resolver.resolver) == address(0)) {
            revert InvalidResolver();
        }
    }

    function registerResolver(address resolver) public returns (ResolverUID _resolverUID) {
        _resolverUID = registry.registerResolver(IExternalResolver(resolver));
    }

    function findModule(address moduleAddress) public view returns (ModuleRecord memory) {
        return registry.findModule(moduleAddress);
    }

    function setRegistry(address _registry) public {
        registry = IRegistry(_registry);
    }

    function setResolverUID(ResolverUID _resolverUID) public {
        resolverUID = _resolverUID;
    }
}
