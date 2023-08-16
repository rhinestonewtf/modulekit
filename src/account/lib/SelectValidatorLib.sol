// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UserOperation} from "@aa/interfaces/UserOperation.sol";

library SelectValidatorLib {
    function decodeSignature(bytes calldata signature) internal returns (address validator) {}

    function decodeValidator(UserOperation calldata userOps) internal returns (address validator) {
        bytes memory addressSplice = userOps.signature[0:20];
        assembly {
            validator := mload(add(addressSplice, 20))
        }
    }

    function encodeValidator(bytes memory signature, address chosenValidator)
        internal
        returns (bytes memory packedSignature)
    {
        packedSignature = abi.encodePacked(chosenValidator, signature);
    }
}
