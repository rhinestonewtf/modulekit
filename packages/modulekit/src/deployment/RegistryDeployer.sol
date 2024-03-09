// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC165 } from "forge-std/interfaces/IERC165.sol";

address constant REGISTRY_ADDR = 0xe0cde9239d16bEf05e62Bbf7aA93e420f464c826;

// Struct that represents Module artefact.
struct ModuleRecord {
    bytes32 resolverUID; // The unique identifier of the resolver.
    address sender; // The address of the sender who deployed the contract
    bytes metadata; // Additional data related to the contract deployment
}

struct ResolverRecord {
    address resolver; // Optional resolver.
    address resolverOwner; // The address of the account used to register the resolver.
}

struct AttestationRecord {
    bytes32 schemaUID; // The unique identifier of the schema.
    address subject; // The recipient of the attestation i.e. module
    address attester; // The attester/sender of the attestation.
    uint48 time; // The time when the attestation was created (Unix timestamp).
    uint48 expirationTime; // The time when the attestation expires (Unix timestamp).
    uint48 revocationTime; // The time when the attestation was revoked (Unix timestamp).
    address dataPointer; // SSTORE2 pointer to the attestation data.
}

contract RegistryDeployer {
    IRegistry registry = IRegistry(REGISTRY_ADDR);
    // Default resolver
    bytes32 resolverUID = 0xdf658e5595d93baa803af242dc6e175b4cbef04de73509b50b944d1b2d167bb6;

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

// Interfaces

interface IResolver is IERC165 {
    /**
     * @dev Returns whether the resolver supports ETH transfers.
     */
    function isPayable() external pure returns (bool);

    /**
     * @dev Processes an attestation and verifies whether it's valid.
     *
     * @param attestation The new attestation.
     *
     * @return Whether the attestation is valid.
     */
    function attest(AttestationRecord calldata attestation) external payable returns (bool);

    /**
     * @dev Processes a Module Registration
     *
     * @param module Module registration artefact
     *
     * @return Whether the registration is valid
     */
    function moduleRegistration(ModuleRecord calldata module) external payable returns (bool);

    /**
     * @dev Processes multiple attestations and verifies whether they are valid.
     *
     * @param attestations The new attestations.
     * @param values Explicit ETH amounts which were sent with each attestation.
     *
     * @return Whether all the attestations are valid.
     */
    function multiAttest(
        AttestationRecord[] calldata attestations,
        uint256[] calldata values
    )
        external
        payable
        returns (bool);

    /**
     * @dev Processes an attestation revocation and verifies if it can be revoked.
     *
     * @param attestation The existing attestation to be revoked.
     *
     * @return Whether the attestation can be revoked.
     */
    function revoke(AttestationRecord calldata attestation) external payable returns (bool);

    /**
     * @dev Processes revocation of multiple attestation and verifies they can be revoked.
     *
     * @param attestations The existing attestations to be revoked.
     * @param values Explicit ETH amounts which were sent with each revocation.
     *
     * @return Whether the attestations can be revoked.
     */
    function multiRevoke(
        AttestationRecord[] calldata attestations,
        uint256[] calldata values
    )
        external
        payable
        returns (bool);
}

interface IRegistry {
    function deploy(
        bytes calldata code,
        bytes calldata deployParams,
        bytes32 salt,
        bytes calldata data,
        bytes32 resolverUID
    )
        external
        payable
        returns (address moduleAddr);

    function deployC3(
        bytes calldata code,
        bytes calldata deployParams,
        bytes32 salt,
        bytes calldata data,
        bytes32 resolverUID
    )
        external
        payable
        returns (address moduleAddr);

    function deployViaFactory(
        address factory,
        bytes calldata callOnFactory,
        bytes calldata data,
        bytes32 resolverUID
    )
        external
        payable
        returns (address moduleAddr);

    function registerResolver(IResolver _resolver) external returns (bytes32);

    function getResolver(bytes32 uid) external view returns (ResolverRecord memory);

    function getModule(address moduleAddress) external view returns (ModuleRecord memory);
}
