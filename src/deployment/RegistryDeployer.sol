// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IRegistry, IExternalResolver } from "registry/IRegistry.sol";
import {
    ResolverRecord,
    ModuleRecord,
    ResolverUID,
    AttestationRecord,
    AttestationRequest,
    ModuleType,
    SchemaUID,
    SchemaRecord
} from "registry/DataTypes.sol";
import { IExternalSchemaValidator } from "registry/external/IExternalSchemaValidator.sol";

address constant REGISTRY_ADDR = 0x0000000000E23E0033C3e93D9D4eBc2FF2AB2AEF;

contract RegistryDeployer {
    IRegistry internal registry = IRegistry(REGISTRY_ADDR);

    // Default resolver
    ResolverUID internal resolverUID =
        ResolverUID.wrap(0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f);

    SchemaUID internal schemaUID =
        SchemaUID.wrap(0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1);

    // Mock attester
    address internal mockAttester = 0xe0cde9239d16bEf05e62Bbf7aA93e420f464c826;

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

    function predictModuleAddress(
        bytes32 salt,
        bytes memory initCode
    )
        public
        view
        returns (address)
    {
        return registry.calcModuleAddress(salt, initCode);
    }

    // <---- ATTESTATIONS ---->

    function mockAttestToModule(
        address module,
        bytes memory attestationData,
        ModuleType[] memory moduleTypes
    )
        public
    {
        SchemaUID _schemaUID = findSchema();
        AttestationRequest memory request = AttestationRequest({
            moduleAddress: module,
            expirationTime: 0,
            data: attestationData,
            moduleTypes: moduleTypes
        });
        registry.attest({
            schemaUID: _schemaUID,
            request: request,
            attester: mockAttester,
            signature: hex"414141414141"
        });
    }

    function isModuleAttestedMock(address module) public view returns (bool) {
        AttestationRecord memory attestation =
            registry.findAttestation({ module: module, attester: mockAttester });
        return attestation.time > 0 && attestation.expirationTime < block.timestamp
            && attestation.revocationTime == 0;
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

    function findSchema() public view returns (SchemaUID _schemaUID) {
        _schemaUID = schemaUID;
        SchemaRecord memory schema = registry.findSchema(schemaUID);
        if (schema.registeredAt == 0) {
            revert InvalidResolver();
        }
    }

    function registerSchema(
        string memory schema,
        address validator
    )
        public
        returns (SchemaUID _schemaUID)
    {
        _schemaUID = registry.registerSchema({
            schema: schema,
            validator: IExternalSchemaValidator(validator)
        });
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

    function setSchemaUID(SchemaUID _schemaUID) public {
        schemaUID = _schemaUID;
    }
}
