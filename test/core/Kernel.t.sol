// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    RhinestoneModuleKitLib,
    RhinestoneAccount
} from "../../src/test/utils/safe-base/RhinestoneModuleKit.sol";

import { MockExecutor } from "../../src/test/mocks/MockExecutor.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import "../../src/core/IRhinestone4337.sol";

import {
    ICondition,
    ConditionConfig,
    ComposableConditionManager
} from "../../src/core/ComposableCondition.sol";

import "../../src/common/FallbackHandler.sol";
import "forge-std/console2.sol";
import "forge-std/interfaces/IERC20.sol";

import "kernel/Kernel.sol";
import "../../src/test/utils/kernel-base/RhinestoneValidator.sol";

contract ModuleKitTemplateTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount; // <-- library that wraps smart account actions for easier testing

    RhinestoneAccount instance; // <-- this is a rhinestone smart account instance

    MockExecutor executor;
    RhinestoneValidator rsExec;

    address receiver;
    MockERC20 token;

    Kernel kernel;

    function setUp() public {
        // setting up receiver address. This is the EOA that this test is sending funds to
        receiver = makeAddr("receiver");

        // setting up mock executor and token
        executor = new MockExecutor();
        token = new MockERC20("", "", 18);

        // create a new rhinestone account instance
        instance = makeRhinestoneAccount("1");
        kernel = new Kernel(instance.aux.entrypoint);

        rsExec = new RhinestoneValidator();

        // dealing ether and tokens to newly created smart account
        vm.deal(instance.account, 10 ether);
        token.mint(instance.account, 100 ether);
    }

    function testKernel() public {
        kernel.setDefaultValidtor(rsExec, "");
    }
}
