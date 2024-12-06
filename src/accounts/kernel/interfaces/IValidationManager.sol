// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IHook, ISigner } from "../../../accounts/common/interfaces/IERC7579Module.sol";

// Types
import { PassFlag, PolicyData, ValidationId, PermissionId } from "../lib/ValidationTypeLib.sol";

// erc7579 plugins
struct ValidationConfig {
    uint32 nonce; // 4 bytes
    IHook hook; // 20 bytes address(1) : hook not required, address(0) : validator not installed
}

struct PermissionConfig {
    PassFlag permissionFlag;
    ISigner signer;
    PolicyData[] policyData;
}

struct ValidationStorage {
    ValidationId rootValidator;
    uint32 currentNonce;
    uint32 validNonceFrom;
    mapping(ValidationId => ValidationConfig) validationConfig;
    mapping(ValidationId => mapping(bytes4 => bool)) allowedSelectors;
    // validation = validator | permission
    // validator == 1 validator
    // permission == 1 signer + N policies
    mapping(PermissionId => PermissionConfig) permissionConfig;
}
