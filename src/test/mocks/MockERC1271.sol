// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../contracts/modules/validators/ISignatureValidator.sol";

contract ERC1271Yes is ISignatureValidator {
    function isValidSignature(
        bytes32,
        bytes memory
    )
        public
        view
        virtual
        override
        returns (bytes4)
    {
        return EIP1271_MAGIC_VALUE;
    }
}

contract ERC1271No is ISignatureValidator {
    function isValidSignature(
        bytes32,
        bytes memory
    )
        public
        view
        virtual
        override
        returns (bytes4)
    {
        return 0xdeadbeef;
    }
}
