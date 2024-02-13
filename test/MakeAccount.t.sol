// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable no-global-import */
import "forge-std/Test.sol";
import "src/ModuleKit.sol";
import "src/Accounts.sol";
import "src/Mocks.sol";
/* solhint-enable no-global-import */

contract BaseTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for RhinestoneAccount;

    MultiAccount multiAccount;
    RhinestoneAccount[] internal diffAccounts;

    RhinestoneAccount internal instance;
    RhinestoneAccount internal instanceSafe;

    address recipient;

    function setUp() public virtual {
        instance = makeRhinestoneAccount("1");
        MockValidator defaultValidator = new MockValidator();
        MockExecutor defaultExecutor = new MockExecutor();
        multiAccount = new MultiAccount(address(defaultValidator), address(defaultExecutor));
        address safe = multiAccount.makeSafe();
        instanceSafe = makeRhinestoneAccount("2", safe, address(defaultValidator), "");
        vm.deal(instanceSafe.account, 1000 ether);
        diffAccounts.push(instance);
        diffAccounts.push(instanceSafe);
        vm.deal(instance.account, 2 ether);

        recipient = makeAddr("recipient");
    }

    function test_transfer() public {
        UserOpData memory data = instance.exec({ target: recipient, value: 1 ether, callData: "" });
        assertTrue(data.userOpHash != "");
        assertTrue(recipient.balance == 1 ether);
        assertTrue(data.userOp.sender == instance.account);
    }
}
