// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    RhinestoneModuleKitLib,
    RhinestoneAccount
} from "../src/test/utils/biconomy-base/RhinestoneModuleKit.sol";

import { MockExecutor } from "../src/test/mocks/MockExecutor.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

import "forge-std/console.sol";

contract ModuleKitTemplateBiconomyTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount; // <-- library that wraps smart account actions for easier testing

    RhinestoneAccount instance; // <-- this is a rhinestone smart account instance

    MockExecutor executor;

    address receiver;
    MockERC20 token;

    function setUp() public {
        // setting up receiver address. This is the EOA that this test is sending funds to
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

    function testSendETH() public {
        // create empty calldata transactions but with specified value to send funds
        instance.exec4337({ target: receiver, value: 10 gwei, callData: "" });
        assertEq(receiver.balance, 10 gwei, "Receiver should have 10 gwei");
    }

    function testMockExecutor() public {
        // add executor to smart account
        instance.addExecutor(address(executor));

        // execute exec() function on executor and bring it to execution on instance of smart account
        instance.exec4337({
            target: address(executor),
            callData: abi.encodeWithSelector(
                MockExecutor.exec.selector,
                instance.aux.executorManager,
                instance.account,
                address(token),
                receiver,
                10
                )
        });

        assertEq(token.balanceOf(receiver), 10, "Receiver should have 10");

        MockExecutor executor2 = new MockExecutor();
        instance.addExecutor(address(executor2));
        instance.removeExecutor(address(executor));
    }
}
