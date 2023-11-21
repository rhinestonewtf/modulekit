// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { RhinestoneSafeFlavor } from
    "../../../../../src/test/utils/safe-base/RhinestoneSafeFlavor.sol";
import { MockRegistry } from "../../../../../src/test/mocks/MockRegistry.sol";
import { ENTRYPOINT_ADDR } from "../../../../../src/test/utils/dependencies/EntryPoint.sol";

contract RhinestoneSafeFlavorTest is Test {
    RhinestoneSafeFlavor safeFlavor;
    MockRegistry mockRegistry;

    function setUp() public {
        mockRegistry = new MockRegistry();
        safeFlavor = new RhinestoneSafeFlavor(ENTRYPOINT_ADDR,mockRegistry);
    }
}
