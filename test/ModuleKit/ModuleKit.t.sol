// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    RhinestoneModuleKitLib,
    RhinestoneAccount
} from "../../src/test/utils/safe-base/RhinestoneModuleKit.sol";

import {MockExecutor} from "../../src/test/mocks/MockExecutor.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract ModuleKitUnitTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount instance;

    MockExecutor executor;

    address receiver;
    MockERC20 token;

    function setUp() public {
        receiver = makeAddr("receiver");

        // setting up mock executor and token
        executor = new MockExecutor();
        token = new MockERC20("", "", 18);

        // create a new rhinestone account instance
        instance = makeRhinestoneAccount("1");

        // dealing ether and tokens to newly created smart account
        vm.deal(instance.account, 10 ether);
        token.mint(instance.account, 100 ether);
    }

    function testManageExecutor() public {
        MockExecutor executor1 = new MockExecutor();
        MockExecutor executor2 = new MockExecutor();
        MockExecutor executor3 = new MockExecutor();
        MockExecutor executor4 = new MockExecutor();
        instance.addExecutor(address(executor1));
        instance.addExecutor(address(executor2));
        instance.addExecutor(address(executor3));
        instance.addExecutor(address(executor4));

        // removing   executor2
        instance.removeExecutor(address(executor2));

        // removing   executor4
        instance.removeExecutor(address(executor4));
        // readding
        instance.addExecutor(address(executor4));
    }

    function testManageValidator() public {
        address validator1 = makeAddr("validator1");
        address validator2 = makeAddr("validator2");
        address validator3 = makeAddr("validator3");

        instance.addValidator(validator1);
        instance.addValidator(validator2);
        instance.addValidator(validator3);

        instance.removeValidator(validator2);
        instance.removeValidator(validator3);

        instance.addValidator(validator3);
        instance.addValidator(validator2);
    }
}

contract ExternalContract {
    uint256 public value;

    function foo(uint256 _value) external {
        value = _value;
    }
}
