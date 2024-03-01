pragma solidity ^0.8.0;

import { PackedUserOperation } from
    "@ERC4337/account-abstraction/contracts/core/UserOperationLib.sol";

import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/modules/ERC7579ValidatorBase.sol";

interface IPolicy {
    function registerPolicy(
        address kernel,
        bytes32 permissionId,
        bytes calldata policyData
    )
        external
        payable;
    function checkUserOpPolicy(
        address kernel,
        bytes32 permissionId,
        PackedUserOperation calldata userOp,
        bytes calldata proofAndSig
    )
        external
        payable
        returns (ERC7579ValidatorBase.ValidationData);

    function validateSignature(
        address kernel,
        address caller,
        bytes32 permissionId,
        bytes32 messageHash,
        bytes32 rawHash,
        bytes calldata signature
    )
        external
        view
        returns (ERC7579ValidatorBase.ValidationData);
}
