// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "src/test/utils/kernel-base/RhinestoneModuleKit.sol";
import "src/test/utils/kernel-base/KernelExecutorManager.sol";
import "src/test/mocks/MockRegistry.sol";
import "src/test/utils/kernel-base/IKernel.sol";
import "src/modulekit/interfaces/IExecutor.sol";

import "src/test/mocks/MockValidator.sol";

contract Target {
    uint256 public value;

    function set(uint256 _value) public returns (uint256) {
        value = _value;
        return _value;
    }
}

contract KernelRhinestoneModuleKitTest is RhinestoneModuleKit, Test {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount instance;
    Target target;
    MockRegistry registry;
    MockValidator validator;

    function setUp() public {
        target = new Target();
        registry = new MockRegistry();
        instance = makeRhinestoneAccount("1");
        validator = new MockValidator();

        vm.deal(instance.account, 1 ether);
    }

    function test_something() public {
        assertTrue(address(instance.account) != address(0));
    }

    function execViaKernel(address to, uint256 value, bytes memory callData) public {
        ExecutorAction memory action =
            ExecutorAction({ to: payable(to), value: value, data: callData });
        ModuleExecLib.exec(instance.executorManager, instance.account, action);
    }

    function test_execViaModule() public {
        vm.prank(address(entrypoint));
        IKernel(instance.account).setDefaultValidator(
            IKernelValidator(address(instance.executorManager)), ""
        );

        console2.log("executorManager", address(instance.executorManager));

        address thisAddress = address(this);
        vm.prank(address(instance.account));
        KernelExecutorManager(address(instance.executorManager)).enableExecutor(thisAddress, false);

        execViaKernel(address(target), 0, abi.encodeWithSelector(target.set.selector, 0x41414141));
    }

    function test_exec4337() public {
        vm.prank(address(entrypoint));
        IKernel(instance.account).setDefaultValidator(
            IKernelValidator(address(instance.executorManager)), ""
        );

        vm.prank(instance.account);
        KernelExecutorManager(address(instance.executorManager)).addValidator(address(validator));
        instance.exec4337({
            target: address(target),
            value: 0,
            callData: abi.encodeWithSelector(target.set.selector, 0x41414141),
            signature: hex"41414141",
            validator: address(validator)
        });

        assertTrue(target.value() == 0x41414141);
    }

    function test_withKit_exec4337() public {
        vm.prank(address(instance.aux.entrypoint));
        instance.exec4337({
            target: address(target),
            callData: abi.encodeWithSelector(target.set.selector, 0x41414141)
        });
        assertTrue(target.value() == 0x41414141);
    }
}
