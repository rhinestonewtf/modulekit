// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

type validatorId is bytes12;

// Validator Data
// This struct is used when configuring a subValidator on MFA, as well as when validating
// signatures.
struct Validator {
    bytes32 packedValidatorAndId; // abi.encodePacked(uint92(id), address(validator))
    bytes data;
}

struct SubValidatorConfig {
    bytes data;
}

struct MFAConfig {
    uint8 threshold;
    uint128 iteration;
}

struct IterativeSubvalidatorRecord {
    mapping(validatorId id => mapping(address account => SubValidatorConfig config)) subValidators;
}
