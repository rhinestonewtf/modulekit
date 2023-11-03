// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./interfaces/IValidator.sol";

abstract contract ValidatorBase is IValidator {
    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    )
        external
        view
        virtual
        override
        returns (bytes4 magicValue);

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        virtual
        override
        returns (uint256);

    function supportsInterface(bytes4 interfaceID) external view virtual override returns (bool) {
        return interfaceID == IERC1271.isValidSignature.selector
            || interfaceID == IValidator.validateUserOp.selector;
    }
}
