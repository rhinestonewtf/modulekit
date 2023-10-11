// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./IValidator.sol";

contract ValidatorBase is IValidator {
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    )
        external
        view
        virtual
        override
        returns (bytes4 magicValue)
    {
        return 0xffffffff;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        virtual
        override
        returns (uint256)
    {
        return VALIDATION_FAILED;
    }
}
