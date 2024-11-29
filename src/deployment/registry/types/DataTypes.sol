// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IExternalSchemaValidator } from "../interfaces/IExternalSchemaValidator.sol";
import { IExternalResolver } from "../interfaces/IExternalResolver.sol";

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                     Storage Structs                        */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

struct AttestationRecord {
    uint48 time; // The time when the attestation was created (Unix timestamp).
    uint48 expirationTime; // The time when the attestation expires (Unix timestamp).
    uint48 revocationTime; // The time when the attestation was revoked (Unix timestamp).
    PackedModuleTypes moduleTypes; // bit-wise encoded module types. See ModuleTypeLib
    address moduleAddress; // The implementation address of the module that is being attested.
    address attester; // The attesting account.
    AttestationDataRef dataPointer; // SSTORE2 pointer to the attestation data.
    SchemaUID schemaUID; // The unique identifier of the schema.
}

struct ModuleRecord {
    ResolverUID resolverUID; // The unique identifier of the resolver.
    address sender; // The address of the sender who deployed the contract
    bytes metadata; // Additional data related to the contract deployment
}

struct SchemaRecord {
    uint48 registeredAt; // The time when the schema was registered (Unix timestamp).
    IExternalSchemaValidator validator; // Optional external schema validator.
    string schema; // Custom specification of the schema (e.g., an ABI).
}

struct ResolverRecord {
    IExternalResolver resolver; // Optional resolver.
    address resolverOwner; // The address of the account used to register the resolver.
}

// Struct that represents a trusted attester.
struct TrustedAttesterRecord {
    uint8 attesterCount; // number of attesters in the linked list
    uint8 threshold; // minimum number of attesters required
    address attester; // first attester in linked list. (packed to save gas)
    mapping(address attester => mapping(address account => address linkedAttester)) linkedAttesters;
}

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*            Attestation / Revocation Requests               */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/**
 * @dev A struct representing the arguments of the attestation request.
 */
struct AttestationRequest {
    address moduleAddress; // The moduleAddress of the attestation.
    uint48 expirationTime; // The time when the attestation expires (Unix timestamp).
    bytes data; // Custom attestation data.
    ModuleType[] moduleTypes; // optional: The type(s) of the module.
}

/**
 * @dev A struct representing the arguments of the revocation request.
 */
struct RevocationRequest {
    address moduleAddress; // The module address.
}

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                       Custom Types                         */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

//---------------------- SchemaUID ------------------------------|
type SchemaUID is bytes32;

using { schemaEq as == } for SchemaUID global;
using { schemaNotEq as != } for SchemaUID global;

function schemaEq(SchemaUID uid1, SchemaUID uid2) pure returns (bool) {
    return SchemaUID.unwrap(uid1) == SchemaUID.unwrap(uid2);
}

function schemaNotEq(SchemaUID uid1, SchemaUID uid2) pure returns (bool) {
    return SchemaUID.unwrap(uid1) != SchemaUID.unwrap(uid2);
}

//--------------------- ResolverUID -----------------------------|
type ResolverUID is bytes32;

using { resolverEq as == } for ResolverUID global;
using { resolverNotEq as != } for ResolverUID global;

function resolverEq(ResolverUID uid1, ResolverUID uid2) pure returns (bool) {
    return ResolverUID.unwrap(uid1) == ResolverUID.unwrap(uid2);
}

function resolverNotEq(ResolverUID uid1, ResolverUID uid2) pure returns (bool) {
    return ResolverUID.unwrap(uid1) != ResolverUID.unwrap(uid2);
}

type AttestationDataRef is address;

using { attestationDataRefEq as == } for AttestationDataRef global;

function attestationDataRefEq(
    AttestationDataRef uid1,
    AttestationDataRef uid2
)
    pure
    returns (bool)
{
    return AttestationDataRef.unwrap(uid1) == AttestationDataRef.unwrap(uid2);
}

type PackedModuleTypes is uint32;

type ModuleType is uint256;

using { moduleTypeEq as == } for ModuleType global;
using { moduleTypeNeq as != } for ModuleType global;

function moduleTypeEq(ModuleType uid1, ModuleType uid2) pure returns (bool) {
    return ModuleType.unwrap(uid1) == ModuleType.unwrap(uid2);
}

function moduleTypeNeq(ModuleType uid1, ModuleType uid2) pure returns (bool) {
    return ModuleType.unwrap(uid1) != ModuleType.unwrap(uid2);
}
