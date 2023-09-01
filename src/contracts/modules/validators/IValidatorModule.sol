// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UserOperation } from "@aa/interfaces/UserOperation.sol";

interface IValidatorModule {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256);

    function recoverValidator(
        address recoveryModule,
        bytes calldata recoveryProof,
        bytes calldata recoveryData
    )
        external;
}
