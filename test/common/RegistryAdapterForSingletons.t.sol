// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import {
    RegistryAdapterForSingletons, IERC7484Registry
} from "../../src/common/IERC7484Registry.sol";
import { MockRegistry } from "../../src/test/mocks/MockRegistry.sol";

contract AdapterInstance is RegistryAdapterForSingletons {
    constructor(IERC7484Registry _registry) RegistryAdapterForSingletons(_registry) { }

    function setAttester(address account, address attester) public {
        _setAttester(account, attester);
    }

    function getAttester(address account) public view returns (address) {
        return trustedAttester[account];
    }

    function enforceRegistryCheck(address executorImpl) public view {
        _enforceRegistryCheck(executorImpl);
    }
}

contract RegistryAdapterForSingletonsTest is Test {
    MockRegistry registry;
    AdapterInstance adapterInstance;

    function setUp() public {
        registry = new MockRegistry();
        adapterInstance = new AdapterInstance(registry);
    }

    function testSetAttester() public {
        address account = makeAddr("account");
        address attester = makeAddr("attester");
        adapterInstance.setAttester(account, attester);
        assertEq(adapterInstance.getAttester(account), attester);
    }

    function testEnforceRegistryCheck() public {
        address executor = makeAddr("executor");
        adapterInstance.enforceRegistryCheck(executor);
    }
}
