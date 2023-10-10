// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../common/IERC1271.sol";

contract ERC1271Yes is IERC1271 {
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
        return ERC1271_MAGICVALUE;
    }
}

contract ERC1271No is IERC1271 {
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
