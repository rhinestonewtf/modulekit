// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../common/erc4337/UserOperation.sol";
import "../common/IERC1271.sol";

uint256 constant VALIDATION_SUCCESS = 0;
uint256 constant VALIDATION_FAILED = 1;

interface IValidator is IERC1271 {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256);
}
