// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { SafeExecutorManager } from "../../../../src/test/utils/safe-base/SafeExecutorManager.sol";
import { MockRegistry } from "../../../../src/test/mocks/MockRegistry.sol";

contract SafeExecutorManagerTest is Test {
    SafeExecutorManager executorManager;
    MockRegistry mockRegistry;

    function setUp() public {
        mockRegistry = new MockRegistry();
        executorManager = new SafeExecutorManager(mockRegistry);
    }
}
