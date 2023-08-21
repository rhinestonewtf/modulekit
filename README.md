# module-boilerplate
Boilerplate for building smart account modules




## Build a Plugin


### Install Rhinestone SDK

```sh
forge install rhinestonewtf/module-kit

```



### Write a Plugin

```solidity
// ./src/MyPlugin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "module-kit/contracts/modules/plugin/IPluginBase.sol";
import "forge-std/interfaces/IERC20.sol";

contract MyPlugin is IPluginBase {
    using ModuleExecLib for IPluginManager; //TODO

    function exec(IPluginManager manager, address account, address token, address receiver, uint256 amount) external {
        manager.exec({
            account: account,
            target: token,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, receiver, amount)
        });
    }

    function name() external view override returns (string memory name) {}

    function version() external view override returns (string memory version) {}

    function metadataProvider() external view override returns (uint256 providerType, bytes memory location) {}

    function requiresRootAccess() external view override returns (bool requiresRootAccess) {}
}
```


### Write a Plugin Test

```solidity
// ./test/MyPlugin.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 


import "forge-std/Test.sol";
import "module-kit/test/utils/safe-base/RhinestoneSDK.sol";


contract PluginTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKit for RhinestoneAccount; // <-- library that wraps smart account actions for easier testing

    RhinestoneAccount instance; // <-- this is a rhinestone smart account instance

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

    function testMockPlugin() public {
        // add plugin to smart account
        instance.addPlugin(address(plugin));

        // execute exec() function on plugin and bring it to execution on instance of smart account
        instance.exec4337({
            target: address(plugin),
            callData: abi.encodeWithSelector(
                MockPlugin.exec.selector, instance.rhinestoneManager, instance.account, address(token), receiver, 10
                )
        });

        assertEq(token.balanceOf(receiver), 10, "Receiver should have 10");

    }

    function testSendETH() public {
        // create empty calldata transactions but with specified value to send funds
        instance.exec4337({target: receiver, value: 10 gwei, callData: ""});
        assertEq(receiver.balance, 10 gwei, "Receiver should have 10 gwei");
    }
}

```
