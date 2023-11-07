// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../common/erc4337/UserOperation.sol";

library ValidatorSelectionLib {
    function decodeSignature(bytes calldata signature) internal returns (address validator) { }

    function decodeValidator(UserOperation calldata userOp)
        internal
        pure
        returns (address validator)
    {
        bytes memory addressSplice = userOp.signature[0:20];
        assembly {
            validator := mload(add(addressSplice, 20))
        }
    }

    function decodeSignature(UserOperation calldata userOp)
        internal
        pure
        returns (bytes memory signature)
    {
        signature = userOp.signature[20:];
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

    function getUserOpTarget(UserOperation calldata _op) internal pure returns (address target) {
        target = address(bytes20(_op.callData[48:68]));
    }

    function getUserOpCallData(UserOperation calldata _op)
        internal
        pure
        returns (bytes4 functionSig, bytes calldata callData)
    {
        functionSig = bytes4(_op.callData[164:168]);
        callData = (_op.callData[168:]);
    }
}
