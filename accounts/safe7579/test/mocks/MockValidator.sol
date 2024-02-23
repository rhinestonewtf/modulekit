// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation } from "erc7579/interfaces/IERC7579Module.sol";
import { MockValidator as MockValidatorBase } from
    "@rhinestone/modulekit/src/mocks/MockValidator.sol";

contract MockValidator is MockValidatorBase {
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        bytes4 execSelector = bytes4(userOp.callData[:4]);

        return VALIDATION_SUCCESS;
    }
}
