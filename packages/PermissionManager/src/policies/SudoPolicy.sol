pragma solidity ^0.8.0;

import { IPolicy, PackedUserOperation } from "../IPolicy.sol";
import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/modules/ERC7579ValidatorBase.sol";

contract SudoPolicy is IPolicy {
    function registerPolicy(
        address kernel,
        bytes32 permissionId,
        bytes calldata data
    )
        external
        payable
        override
    { }

    function checkUserOpPolicy(
        address kernel,
        bytes32 permissionId,
        PackedUserOperation calldata userOp,
        bytes calldata
    )
        external
        payable
        override
        returns (ERC7579ValidatorBase.ValidationData)
    {
        return ERC7579ValidatorBase.ValidationData.wrap(0);
    }

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
        override
        returns (ERC7579ValidatorBase.ValidationData)
    {
        return ERC7579ValidatorBase.ValidationData.wrap(0);
    }
}
