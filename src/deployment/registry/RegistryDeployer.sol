// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IRegistry, IExternalResolver } from "./interfaces/IRegistry.sol";
import { IExternalSchemaValidator } from "./interfaces/IExternalSchemaValidator.sol";

// Types
import {
    ResolverRecord,
    ModuleRecord,
    ResolverUID,
    AttestationRecord,
    AttestationRequest,
    ModuleType,
    SchemaUID,
    SchemaRecord
} from "./types/DataTypes.sol";

/// @dev Preset registry address
address constant REGISTRY_ADDR = 0x000000000069E2a187AEFFb852bF3cCdC95151B2;

contract RegistryDeployer {
    IRegistry internal registry = IRegistry(REGISTRY_ADDR);

    // Default resolver
    ResolverUID internal resolverUID =
        ResolverUID.wrap(0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f);

    SchemaUID internal schemaUID =
        SchemaUID.wrap(0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1);

    address internal mockAttester = 0xA4C777199658a41688E9488c4EcbD7a2925Cc23A;

    error InvalidResolver();

    /*//////////////////////////////////////////////////////////////
                               DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                              REGISTRATION
    //////////////////////////////////////////////////////////////*/

    function registerModule(
        address module,
        bytes memory metadata,
        bytes memory resolverContext
    )
        public
    {
        ResolverUID _resolverUID = findResolver();
        registry.registerModule({
            resolverUID: _resolverUID,
            moduleAddress: module,
            metadata: metadata,
            resolverContext: resolverContext
        });
    }

    function findModule(address moduleAddress) public view returns (ModuleRecord memory) {
        return registry.findModule(moduleAddress);
    }

    /*//////////////////////////////////////////////////////////////
                              ATTESTATION
    //////////////////////////////////////////////////////////////*/

    function mockAttestToModule(
        address module,
        bytes memory attestationData,
        ModuleType[] memory moduleTypes
    )
        public
    {
        // solhint-disable-next-line gas-custom-errors
        require(isContract(mockAttester), "MockAttester not deployed");

        SchemaUID _schemaUID = findSchema();
        AttestationRequest memory request = AttestationRequest({
            moduleAddress: module,
            expirationTime: 0,
            data: attestationData,
            moduleTypes: moduleTypes
        });
        (bool success,) = mockAttester.call(
            abi.encodeWithSignature(
                "attest(address,bytes32,(address,uint48,bytes,uint256[]))",
                REGISTRY_ADDR,
                _schemaUID,
                request
            )
        );

        // solhint-disable-next-line gas-custom-errors
        require(success, "Mock attestation failed");
    }

    function isModuleAttestedMock(address module) public view returns (bool) {
        AttestationRecord memory attestation =
            registry.findAttestation({ module: module, attester: mockAttester });
        return attestation.time > 0 && attestation.expirationTime < block.timestamp
            && attestation.revocationTime == 0;
    }

    /*//////////////////////////////////////////////////////////////
                               MANAGEMENT
    //////////////////////////////////////////////////////////////*/

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

    function setRegistry(address _registry) public {
        registry = IRegistry(_registry);
    }

    function setResolverUID(ResolverUID _resolverUID) public {
        resolverUID = _resolverUID;
    }

    function setSchemaUID(SchemaUID _schemaUID) public {
        schemaUID = _schemaUID;
    }

    /*//////////////////////////////////////////////////////////////
                                 OTHER
    //////////////////////////////////////////////////////////////*/

    function isContract(address _addr) internal view returns (bool _isContract) {
        uint32 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
