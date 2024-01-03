// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "src/ModuleKit.sol";
import "src/Mocks.sol";

contract BaseTest is RhinestoneModuleKit, Test {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount instance;

    function setUp() public {
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 1 ether);
    }

    function test_isDefaultValidatorEnabled() public {
        assertTrue(instance.isValidatorInstalled(address(instance.defaultValidator)));
    }
}
