// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/test/utils/safe-base/RhinestoneSDK.sol";

import "../src/test/mocks/MockPlugin.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "forge-std/interfaces/IERC20.sol";

contract PluginTest is Test, RhinestoneSDK {
    using RhinestoneSDKLib for AccountInstance;

    AccountInstance instance;

    function setUp() public {
        instance = newInstance("1");
        vm.deal(instance.account, 10 ether);
    }

    function testSendETH() public {
        address receiver = makeAddr("receiver");
        instance.exec4337({target: receiver, value: 10 gwei, callData: ""});
        assertEq(receiver.balance, 10 gwei, "Receiver should have 10 gwei");
    }

    function testMocklugin() public {
        MockERC20 token = new MockERC20("","",18);
        token.mint(instance.account, 100 ether);
        address receiver = makeAddr("receiver");

        MockPlugin plugin = new MockPlugin();
        instance.addPlugin(address(plugin));

        instance.exec4337({
            target: address(plugin),
            callData: abi.encodeWithSelector(
                MockPlugin.exec.selector, instance.rhinestoneManager, instance.account, IERC20(address(token)), receiver, 10
                )
        });
        assertEq(token.balanceOf(receiver), 10, "Receiver should have 10");
    }
}
