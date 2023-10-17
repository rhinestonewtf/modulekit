// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UserOperation } from "../common/erc4337/UserOperation.sol";
import "../common/IERC1271.sol";
import "forge-std/interfaces/IERC165.sol";

uint256 constant VALIDATION_SUCCESS = 0;
uint256 constant VALIDATION_FAILED = 1;

interface IValidator is IERC1271, IERC165 {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256);
}
