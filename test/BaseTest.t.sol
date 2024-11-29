// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import "forge-std/Test.sol";
import "src/ModuleKit.sol";
import "src/Accounts.sol";
import "src/Mocks.sol";
import { Execution } from "src/accounts/erc7579/lib/ExecutionLib.sol";

contract BaseTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for AccountInstance;

    AccountInstance internal instance;
    AccountInstance internal instanceSafe;

    address recipient;

    function setUp() public virtual {
        instance = makeAccountInstance("account1");

        // MockValidator defaultValidator = new MockValidator();
        // MockExecutor defaultExecutor = new MockExecutor();
        vm.deal(instanceSafe.account, 1000 ether);
        vm.deal(instance.account, 2 ether);

        recipient = makeAddr("recipient");
    }
}
