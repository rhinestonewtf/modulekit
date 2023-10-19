// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../../../src/modulekit/ConditionalExecutorBase.sol";
import "../../../src/modulekit/integrations/ERC20Actions.sol";
import { ModuleExecLib } from "../../../src/modulekit/IExecutor.sol";
import "../../../src/modulekit/conditions/ScheduleCondition.sol";
import "../../../src/core/ComposableCondition.sol";

contract ScheduleExecutor is ConditionalExecutor {
    using ModuleExecLib for IExecutorManager;

    ScheduleCondition immutable scheduler;

    error MissingCondition();

    constructor(
        ScheduleCondition _scheduler,
        ComposableConditionManager conditionManger
    )
        ConditionalExecutor(conditionManger)
    {
        scheduler = _scheduler;
    }

    function _checkIfSchedulerIsUsed(ConditionConfig[] calldata conditions) private {
        uint256 length = conditions.length;
        uint256 i;
        for (; i < length; i++) {
            if (address(conditions[i].condition) == address(scheduler)) {
                return;
            }
        }

        revert MissingCondition();
    }

    /**
     * @dev Modifier to ensure the conditions are met before executing a function.
     * @dev overwritten to update schedule condition post execution.
     * @param account The address against which the conditions are checked.
     * @param conditions Array of conditions to be checked.
     */
    modifier onlyIfConditionsMet(address account, ConditionConfig[] calldata conditions) override {
        _checkIfSchedulerIsUsed(conditions);
        _checkConditions(account, conditions);
        _;
        scheduler.updateSchedule(account);
    }

    function sendToken(
        IExecutorManager manager,
        address account,
        ConditionConfig[] calldata conditions,
        IERC20 token,
        address receiver,
        uint256 amount
    )
        external
        onlyIfConditionsMet(account, conditions)
    {
        ExecutorAction[] memory actions = new ExecutorAction[](1);
        actions[0] = ERC20ModuleKit.transferAction({ token: token, to: receiver, amount: amount });
        manager.exec({ account: account, actions: actions });
    }

    function name() external view override returns (string memory name) { }

    function version() external view override returns (string memory version) { }

    function metadataProvider()
        external
        view
        override
        returns (uint256 providerType, bytes memory location)
    { }

    function requiresRootAccess() external view override returns (bool requiresRootAccess) { }
}

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    RhinestoneModuleKitLib,
    RhinestoneAccount
} from "../../../src/test/utils/safe-base/RhinestoneModuleKit.sol";

import { MockExecutor } from "../../../src/test/mocks/MockExecutor.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import "../../../src/core/IRhinestone4337.sol";

import {
    ICondition,
    ConditionConfig,
    ComposableConditionManager
} from "../../../src/core/ComposableCondition.sol";

import "../../../src/common/FallbackHandler.sol";
import "forge-std/console2.sol";
import "forge-std/interfaces/IERC20.sol";

contract ScheduleExecutorTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount; // <-- library that wraps smart account actions for easier testing

    RhinestoneAccount instance; // <-- this is a rhinestone smart account instance

    address receiver;
    MockERC20 token;

    ScheduleExecutor executor;
    ScheduleCondition condition;
    ComposableConditionManager conditionManager;

    function setUp() public {
        // setting up receiver address. This is the EOA that this test is sending funds to
        receiver = makeAddr("receiver");

        token = new MockERC20("", "", 18);

        // create a new rhinestone account instance
        instance = makeRhinestoneAccount("1");
        condition = new ScheduleCondition();
        conditionManager = new ComposableConditionManager(instance.aux.registry);
        executor = new ScheduleExecutor(condition, conditionManager);

        // dealing ether and tokens to newly created smart account
        vm.deal(instance.account, 10 ether);
        token.mint(instance.account, 100 ether);
    }

    function test_TriggerExecutor() public {
        address relay = makeAddr("relay");

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] = ConditionConfig({
            condition: ICondition(address(condition)),
            conditionData: abi.encode(ScheduleCondition.Params({ triggerEveryHours: 1 }))
        });

        instance.addExecutor(address(executor));

        vm.prank(instance.account);
        conditionManager.setHash(address(executor), conditions);

        vm.warp(1_600_000);

        executor.sendToken(
            IExecutorManager(address(instance.aux.executorManager)),
            instance.account,
            conditions,
            IERC20(address(token)),
            receiver,
            10
        );

        assertEq(token.balanceOf(receiver), 10);
        vm.warp(1_600_001);

        vm.expectRevert();
        executor.sendToken(
            IExecutorManager(address(instance.aux.executorManager)),
            instance.account,
            conditions,
            IERC20(address(token)),
            receiver,
            10
        );
    }
}
