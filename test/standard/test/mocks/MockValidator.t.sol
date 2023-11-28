// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { MockValidator } from "../../../../src/test/mocks/MockValidator.sol";
import { UserOperation, getEmptyUserOp } from "../../../TestUtils.t.sol";

contract MockValidatorTest is Test {
    MockValidator mockValidator;

    function setUp() public {
        mockValidator = new MockValidator();
    }

    function testValidateUserOp() public {
        UserOperation memory userOp = getEmptyUserOp();
        uint256 result = mockValidator.validateUserOp(userOp, bytes32(0));

        assertEq(result, 0);
    }

    function testIsValidSignature() public {
        bytes4 result = mockValidator.isValidSignature(bytes32(0), bytes(""));
        assertEq(bytes32(result), bytes32(bytes4(0x1626ba7e)));
    }
}
