// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { ERC2771Context } from "../../../src/common/ERC2771Context.sol";

contract ERC2771ContextInstance is ERC2771Context {
    function msgSender() public view returns (address) {
        return _msgSender();
    }

    function manager() public view returns (address) {
        return _manager();
    }

    function gated() public onlySmartAccount { }
}

contract ERC2771ContextTest is Test {
    ERC2771ContextInstance context;

    function setUp() public {
        context = new ERC2771ContextInstance();
    }

    function testMsgSender() public {
        address sender = makeAddr("sender");
        (bool success, bytes memory result) =
            address(context).call(abi.encodePacked(bytes4(keccak256("msgSender()")), sender));
        address returnAddr;
        assembly {
            returnAddr := mload(add(result, 32))
        }
        assertTrue(success);
        assertEq(returnAddr, sender);
    }

    function testManager() public {
        address manager = context.manager();
        assertEq(address(this), manager);
    }

    function testOnlySmartAccount() public {
        (bool success, bytes memory result) =
            address(context).call(abi.encodePacked(bytes4(keccak256("gated()")), address(this)));
        assertTrue(success);
    }

    function testOnlySmartAccount__RevertWhen__NotMsgSender() public {
        vm.expectRevert();
        context.gated();
    }
}
