// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.t.sol";

interface IERC4337 {
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        payable
        returns (uint256 validSignature);
}

contract ERC4337Test is BaseTest {
    bytes _calldata;
    uint256 _ret;
    bytes32 _userOpHash;

    function setUp() public virtual override {
        super.setUp();
        installUnitTestAsModule();
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (uint256)
    {
        assertEq(msg.sender, address(account));
        assertEq(userOp.callData, _calldata);
        assertEq(userOpHash, _userOpHash);
        return _ret;
    }

    function test_WhenCallingValidateFunction(
        bytes32 userOpHash,
        uint256 ret
    )
        external
        asEntryPoint
    {
        // It should select the correct validator module
        _ret = ret;
        _calldata = hex"41414141";
        _userOpHash = userOpHash;

        PackedUserOperation memory userOp = getDefaultUserOp(address(safe), address(SELF));
        userOp.callData = _calldata;

        uint256 rett = IERC4337(address(account)).validateUserOp(userOp, userOpHash, 100);

        assertEq(rett, ret);
    }

    function test_WhenEncodingAnInvalidValidatorModule(
        bytes32 userOpHash,
        uint256 ret
    )
        external
        asEntryPoint
    {
        // It should fallback to safe signature checks
        _ret = ret;
        _calldata = hex"41414141";
        _userOpHash = userOpHash;

        PackedUserOperation memory userOp = getDefaultUserOp(address(safe), address(0));
        userOp.callData = _calldata;
        userOp.signature = abi.encodePacked(uint48(0), uint48(type(uint48).max), hex"41414141");

        // TODO: check return
        uint256 rett = IERC4337(address(account)).validateUserOp(userOp, userOpHash, 100);
    }
}
