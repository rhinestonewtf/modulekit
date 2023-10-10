// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../common/erc4337/UserOperation.sol";

library SelectValidatorLib {
    function decodeSignature(bytes calldata signature) internal returns (address validator) { }

    function decodeValidator(UserOperation calldata userOps)
        internal
        pure
        returns (address validator)
    {
        bytes memory addressSplice = userOps.signature[0:20];
        assembly {
            validator := mload(add(addressSplice, 20))
        }
    }

    function decodeSignature(UserOperation calldata userOps)
        internal
        pure
        returns (bytes memory signature)
    {
        signature = userOps.signature[20:];
    }

    function encodeValidator(
        bytes memory signature,
        address chosenValidator
    )
        internal
        pure
        returns (bytes memory packedSignature)
    {
        packedSignature = abi.encodePacked(chosenValidator, signature);
    }
}
