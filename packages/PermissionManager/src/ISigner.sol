pragma solidity ^0.8.0;

import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/modules/ERC7579ValidatorBase.sol";

interface ISigner {
    function registerSigner(
        address kernel,
        bytes32 permissionId,
        bytes calldata signerData
    )
        external
        payable;
    function validateUserOp(
        address kernel,
        bytes32 permissionId,
        bytes32 userOpHash,
        bytes calldata signature
    )
        external
        payable
        returns (ERC7579ValidatorBase.ValidationData);
    function validateSignature(
        address kernel,
        bytes32 permissionId,
        bytes32 messageHash,
        bytes calldata signature
    )
        external
        view
        returns (ERC7579ValidatorBase.ValidationData);
}
