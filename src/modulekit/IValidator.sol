// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../common/erc4337/UserOperation.sol";

uint256 constant VALIDATION_SUCCESS = 0;

interface IValidatorModule {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256);
}
