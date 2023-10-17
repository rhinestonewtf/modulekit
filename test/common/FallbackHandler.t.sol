// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { FallbackHandler } from "../../src/common/FallbackHandler.sol";

contract FallbackHandlerInstance is FallbackHandler { }

contract FallbackHandlerTest is Test {
    FallbackHandlerInstance handler;

    function setUp() public {
        handler = new FallbackHandlerInstance();
    }

    // @TODO
    // function testFallback() public {
    //     bytes4 selector = bytes4(keccak256("selector"));
    //     bytes32 newMethod = bytes32(uint256(0x01) << 160 | uint160(address(this)));
    //     handler.setSafeMethod(selector, newMethod);

    //     (bool success, bytes memory result) = address(handler).call(abi.encode());
    //     assertTrue(success);
    // }

    // function testFallback__RevertWhen__InvalidMethodSelector() public {
    //     vm.expectRevert();
    //     address(handler).call(abi.encode());
    // }

    // function testFallback__RevertWhen__HandlerNotSet() public {
    //     vm.expectRevert();
    //     (bool success, bytes memory result) =
    //         address(handler).call(abi.encodePacked(bytes4(keccak256("selector")), address(0)));
    //     assertFalse(success);
    // }
}
