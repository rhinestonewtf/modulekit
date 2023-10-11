// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { MockRegistry } from "../../../src/test/mocks/MockRegistry.sol";

contract MockRegistryTest is Test {
    MockRegistry mockRegistry;

    function setUp() public {
        mockRegistry = new MockRegistry();
    }

    function testCheck() public {
        uint256 result = mockRegistry.check(address(0), address(0));

        assertGt(result, 0);
    }

    function testCheckN() public {
        address[] memory attesters = new address[](1);
        attesters[0] = address(0);
        uint256[] memory results = mockRegistry.checkN(address(0), attesters, 0);

        for (uint256 i; i < results.length; ++i) {
            assertGt(results[i], 0);
        }
    }
}
