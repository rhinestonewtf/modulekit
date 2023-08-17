// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "./utils/safe-base/AccountFactory.sol";
import "./utils/safe-base/RhinestoneUtil.sol";

import "../src/modules/plugin/TemplatePlugin.sol";
import "solady/test/uitls/MockERC20.sol";
/// @title ExampleTestSafeBase
/// @author zeroknots

contract ExampleTestSafeBase is AccountFactory, Test {
    using RhinestoneUtil for AccountInstance;

    AccountInstance smartAccount;

    function setUp() public {
        smartAccount = newInstance("1");
        vm.deal(smartAccount.account, 10 ether);
    }

    function testSendEth() public {
        address receiver = makeAddr("receiver");
        smartAccount.exec4337({target: receiver, value: 10 gwei, callData: ""});
        assertEq(receiver.balance, 10 gwei, "Receiver should have 10 gwei");
    }

    function testAddPlugin() public {
        TemplatePlugin plugin = new TemplatePlugin();
        smartAccount.addPlugin(address(plugin));

        smartAccount.exec4337({target: address(plugin), callData: abi.encodeWithSelector(TemplatePlugin.exec.selector)});
    }
}
