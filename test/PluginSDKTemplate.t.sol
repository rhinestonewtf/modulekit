// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/test/utils/safe-base/RhinestoneSDK.sol";

import "../src/test/mocks/MockPlugin.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

contract PluginTest is Test, RhinestoneSDK {
    using RhinestoneSDKLib for AccountInstance; // <-- library that wraps smart account actions for easier testing

    AccountInstance instance; // <-- this is a rhinestone smart account instance

    MockPlugin plugin;

    address receiver;
    MockERC20 token;

    function setUp() public {
        // setting up receiver address. This is the EOA that this test is sending funds to
        receiver = makeAddr("receiver");

        // setting up mock plugin and token
        plugin = new MockPlugin();
        token = new MockERC20("","",18);

        // create a new rhinestone account instance
        instance = newInstance("1");

        // dealing ether and tokens to newly created smart account
        vm.deal(instance.account, 10 ether);
        token.mint(instance.account, 100 ether);
    }

    function testSendETH() public {
        // create empty calldata transactions but with specified value to send funds
        instance.exec4337({target: receiver, value: 10 gwei, callData: ""});
        assertEq(receiver.balance, 10 gwei, "Receiver should have 10 gwei");
    }

    function testMockPlugin() public {
        // add plugin to smart account
        instance.addPlugin(address(plugin));

        // execute exec() function on plugin and bring it to execution on instance of smart account
        instance.exec4337({
            target: address(plugin),
            callData: abi.encodeWithSelector(
                MockPlugin.exec.selector, instance.aux.pluginManager, instance.account, address(token), receiver, 10
                )
        });

        assertEq(token.balanceOf(receiver), 10, "Receiver should have 10");

        MockPlugin plugin2 = new MockPlugin();
        instance.addPlugin(address(plugin2));
        instance.removePlugin(address(plugin));
    }
}
