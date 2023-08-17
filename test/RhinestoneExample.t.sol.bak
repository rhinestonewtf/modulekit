// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/test/utils/safe-base/AccountFactory.sol";
import "../src/test/utils/safe-base/RhinestoneUtil.sol";
import "../src/contracts/auxiliary/interfaces/IModuleManager.sol";

import "../src/contracts/modules/plugin/TemplatePlugin.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "forge-std/interfaces/IERC20.sol";
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
        MockERC20 token = new MockERC20("","",18);
        token.mint(smartAccount.account, 100 ether);
        address receiver = makeAddr("receiver");

        TemplatePlugin plugin = new TemplatePlugin();
        smartAccount.addPlugin(address(plugin));

        console2.log("calling 4337");
        smartAccount.exec4337({
            target: address(plugin),
            callData: abi.encodeWithSelector(
                TemplatePlugin.exec.selector,
                smartAccount.rhinestoneManager,
                smartAccount.account,
                IERC20(address(token)),
                receiver,
                10
                )
        });
        assertEq(token.balanceOf(receiver), 10, "Receiver should have 10");
    }
}
