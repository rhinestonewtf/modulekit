// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.t.sol";

contract ERC1271Test is BaseTest {
    address _sender;
    bytes32 _hash;
    bytes _data;
    bytes4 _erc1271Selector;

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        // It should forward the correct msgSender
        assertEq(msg.sender, address(account));
        assertEq(sender, _sender);
        assertEq(hash, _hash);
        // It should slice the correct signature
        assertEq(data, _data);
        return _erc1271Selector;
    }

    function test_WhenForwardingERC1271(bytes4 selector) external {
        installUnitTestAsModule();
        // It should select the correct validator
        _erc1271Selector = selector;
        _hash = bytes32("foo");
        _data = abi.encodePacked(hex"4141414141");
        _sender = SELF;
        bytes4 ret = account.isValidSignature(_hash, abi.encodePacked(SELF, _data));
        assertEq(ret, _erc1271Selector);
    }
}
