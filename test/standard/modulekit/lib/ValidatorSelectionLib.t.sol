// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { ValidatorSelectionLib } from "../../../../src/modulekit/lib/ValidatorSelectionLib.sol";
import { UserOperation, getEmptyUserOp } from "../../../TestUtils.t.sol";

contract ValidatorSelectionLibImplementation {
    function decodeValidator(UserOperation calldata userOp)
        external
        pure
        returns (address validator)
    {
        validator = ValidatorSelectionLib.decodeValidator(userOp);
    }

    function decodeSignature(UserOperation calldata userOp)
        external
        pure
        returns (bytes memory signature)
    {
        signature = ValidatorSelectionLib.decodeSignature(userOp);
    }

    function encodeValidator(
        bytes memory signature,
        address chosenValidator
    )
        external
        pure
        returns (bytes memory packedSignature)
    {
        packedSignature = ValidatorSelectionLib.encodeValidator(signature, chosenValidator);
    }
}

contract ValidatorSelectionLibTest is Test {
    ValidatorSelectionLibImplementation impl;

    function setUp() public {
        impl = new ValidatorSelectionLibImplementation();
    }

    function testDecodeValidator() public {
        UserOperation memory userOp = getEmptyUserOp();

        address validator = makeAddr("validator");
        bytes memory signature = bytes("signature");
        bytes memory signatureEncoded = impl.encodeValidator(signature, validator);
        userOp.signature = signatureEncoded;
        address decodedValidator = impl.decodeValidator(userOp);

        assertEq(decodedValidator, validator);
    }

    function testDecodeSignature() public {
        UserOperation memory userOp = getEmptyUserOp();

        address validator = makeAddr("validator");
        bytes memory signature = bytes("signature");
        bytes memory signatureEncoded = impl.encodeValidator(signature, validator);
        userOp.signature = signatureEncoded;
        bytes memory signatureDecoded = impl.decodeSignature(userOp);

        assertEq(signatureDecoded, signature);
    }

    function testEncodeValidator() public {
        address validator = makeAddr("validator");
        bytes memory signature = bytes("signature");
        bytes memory signatureEncoded = abi.encode(signature, validator);
        bytes memory signatureEncodedWithLib = impl.encodeValidator(signature, validator);

        assertEq(signatureEncodedWithLib, signatureEncoded);
    }
}
