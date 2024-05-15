// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import { ScheduledTransfers, SchedulingBase } from "src/ScheduledTransfers/ScheduledTransfers.sol";
import { IERC7579Module, Execution } from "modulekit/src/external/ERC7579.sol";
import { MockTarget } from "test/mocks/MockTarget.sol";

contract ScheduledTransfersTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ScheduledTransfers internal executor;
    MockTarget internal target;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();

        executor = new ScheduledTransfers();
        target = new MockTarget();

        vm.warp(1_713_357_071);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      UTILS
    //////////////////////////////////////////////////////////////////////////*/

    function checkExecutionDataAdded(
        address smartAccount,
        uint256 jobId,
        uint48 _executeInterval,
        uint16 _numberOfExecutions,
        uint48 _startDate,
        bytes memory _executionData
    )
        internal
    {
        (
            uint48 executeInterval,
            uint16 numberOfExecutions,
            uint16 numberOfExecutionsCompleted,
            uint48 startDate,
            bool isEnabled,
            uint48 lastExecutionTime,
            bytes memory executionData
        ) = executor.executionLog(smartAccount, jobId);
        assertEq(executeInterval, _executeInterval);
        assertEq(numberOfExecutions, _numberOfExecutions);
        assertEq(startDate, _startDate);
        assertEq(isEnabled, true);
        assertEq(lastExecutionTime, 0);
        assertEq(numberOfExecutionsCompleted, 0);
        assertEq(executionData, _executionData);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        uint48 _executeInterval = 1 days;
        uint16 _numberOfExecutions = 10;
        uint48 _startDate = uint48(block.timestamp);
        Execution memory _execution =
            Execution({ target: address(0x1), value: 100, callData: bytes("") });
        bytes memory _executionData = abi.encode(_execution);
        bytes memory data =
            abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _executionData);

        executor.onInstall(data);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.AlreadyInitialized.selector, address(this))
        );
        executor.onInstall(data);
    }

    function test_OnInstallWhenModuleIsNotIntialized() public {
        // it should set the jobCount to 1
        // it should store the execution config
        // it should emit an ExecutionAdded event
        uint48 _executeInterval = 1 days;
        uint16 _numberOfExecutions = 10;
        uint48 _startDate = uint48(block.timestamp);
        Execution memory _execution =
            Execution({ target: address(0x1), value: 100, callData: bytes("") });
        bytes memory _executionData = abi.encode(_execution);
        bytes memory data =
            abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _executionData);

        vm.expectEmit(true, true, true, true, address(executor));
        emit SchedulingBase.ExecutionAdded({ smartAccount: address(this), jobId: 1 });

        executor.onInstall(data);

        uint256 jobCount = executor.accountJobCount(address(this));
        assertEq(jobCount, 1);

        checkExecutionDataAdded(
            address(this), 1, _executeInterval, _numberOfExecutions, _startDate, _executionData
        );
    }

    function test_OnUninstallShouldRemoveAllExecutions() public {
        // it should remove all executions
        test_OnInstallWhenModuleIsNotIntialized();

        uint256 jobCount = executor.accountJobCount(address(this));

        executor.onUninstall("");

        for (uint256 i; i < jobCount; i++) {
            (
                uint48 executeInterval,
                uint16 numberOfExecutions,
                uint16 numberOfExecutionsCompleted,
                uint48 startDate,
                bool isEnabled,
                uint48 lastExecutionTime,
                bytes memory executionData
            ) = executor.executionLog(address(this), i);
            assertEq(executeInterval, uint48(0));
            assertEq(numberOfExecutions, uint16(0));
            assertEq(startDate, uint48(0));
            assertEq(isEnabled, false);
            assertEq(lastExecutionTime, 0);
            assertEq(numberOfExecutionsCompleted, 0);
            assertEq(executionData, "");
        }
    }

    function test_OnUninstallShouldSetTheAccountJobCountTo0() public {
        // it should set the account job count to 0
        test_OnInstallWhenModuleIsNotIntialized();

        executor.onUninstall("");

        uint256 jobCount = executor.accountJobCount(address(this));
        assertEq(jobCount, 0);
    }

    function test_OnUninstallShouldEmitAnExecutionsCancelledEvent() public {
        // it should emit an ExecutionsCancelled event
        test_OnInstallWhenModuleIsNotIntialized();

        vm.expectEmit(true, true, true, true, address(executor));
        emit SchedulingBase.ExecutionsCancelled({ smartAccount: address(this) });
        executor.onUninstall("");
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool isInitialized = executor.isInitialized(address(this));
        assertFalse(isInitialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenModuleIsNotIntialized();

        bool isInitialized = executor.isInitialized(address(this));
        assertTrue(isInitialized);
    }

    function test_AddOrderRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        uint48 _executeInterval = 1 days;
        uint16 _numberOfExecutions = 10;
        uint48 _startDate = uint48(block.timestamp);
        Execution memory _execution =
            Execution({ target: address(0x1), value: 100, callData: bytes("") });
        bytes memory _executionData = abi.encode(_execution);
        bytes memory data =
            abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _executionData);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        executor.addOrder(data);
    }

    function test_AddOrderWhenModuleIsIntialized() public {
        // it should increment the jobCount by 1
        // it should store the execution config
        // it should emit an ExecutionAdded event
        test_OnInstallWhenModuleIsNotIntialized();

        uint48 _executeInterval = 1 days;
        uint16 _numberOfExecutions = 10;
        uint48 _startDate = uint48(block.timestamp);
        Execution memory _execution =
            Execution({ target: address(0x1), value: 100, callData: bytes("") });
        bytes memory _executionData = abi.encode(_execution);
        bytes memory data =
            abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _executionData);

        uint256 prevJobCount = executor.accountJobCount(address(this));

        vm.expectEmit(true, true, true, true, address(executor));
        emit SchedulingBase.ExecutionAdded({ smartAccount: address(this), jobId: prevJobCount + 1 });

        executor.addOrder(data);

        uint256 jobCount = executor.accountJobCount(address(this));
        assertEq(jobCount, prevJobCount + 1);

        checkExecutionDataAdded(
            address(this), 1, _executeInterval, _numberOfExecutions, _startDate, _executionData
        );
    }

    function test_ToggleOrderRevertWhen_OrderDoesNotExist() public {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();

        vm.expectRevert(abi.encodeWithSelector(SchedulingBase.InvalidExecution.selector));
        executor.toggleOrder(2);
    }

    function test_ToggleOrderWhenOrderExists() public {
        // it should toggle the order enabled state
        // it should emit an ExecutionStatusUpdated event
        test_OnInstallWhenModuleIsNotIntialized();

        uint256 jobId = 1;

        vm.expectEmit(true, true, true, true, address(executor));
        emit SchedulingBase.ExecutionStatusUpdated({ smartAccount: address(this), jobId: jobId });

        executor.toggleOrder(jobId);

        (,,,, bool isEnabled,,) = executor.executionLog(address(this), jobId);
        assertFalse(isEnabled);
    }

    function test_ExecuteOrderRevertWhen_OrderIsNotEnabled() public {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();
        uint256 jobId = 1;
        executor.toggleOrder(jobId);

        vm.startPrank(address(target));
        vm.expectRevert(abi.encodeWithSelector(SchedulingBase.InvalidExecution.selector));
        executor.executeOrder(jobId);
        vm.stopPrank();
    }

    function test_ExecuteOrderRevertWhen_TheOrderIsNotDue() public whenOrderIsEnabled {
        // it should revert
        uint48 _executeInterval = 1 days;
        uint16 _numberOfExecutions = 10;
        uint48 _startDate = uint48(block.timestamp);
        Execution memory _execution =
            Execution({ target: address(0x1), value: 100, callData: bytes("") });
        bytes memory _executionData = abi.encode(_execution);
        bytes memory data =
            abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _executionData);

        vm.prank(address(target));
        executor.onInstall(data);

        uint256 jobId = 1;

        checkExecutionDataAdded(
            address(target),
            jobId,
            _executeInterval,
            _numberOfExecutions,
            _startDate,
            _executionData
        );

        vm.startPrank(address(target));
        executor.executeOrder(jobId);

        vm.expectRevert(abi.encodeWithSelector(SchedulingBase.InvalidExecution.selector));
        executor.executeOrder(jobId);
        vm.stopPrank();
    }

    function test_ExecuteOrderRevertWhen_AllExecutionsHaveBeenCompleted()
        public
        whenOrderIsEnabled
        whenTheOrderIsDue
    {
        // it should revert
        uint48 _executeInterval = 1 days;
        uint16 _numberOfExecutions = 1;
        uint48 _startDate = uint48(block.timestamp);
        Execution memory _execution =
            Execution({ target: address(0x1), value: 100, callData: bytes("") });
        bytes memory _executionData = abi.encode(_execution);
        bytes memory data =
            abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _executionData);

        vm.prank(address(target));
        executor.onInstall(data);

        uint256 jobId = 1;

        checkExecutionDataAdded(
            address(target),
            jobId,
            _executeInterval,
            _numberOfExecutions,
            _startDate,
            _executionData
        );

        vm.startPrank(address(target));
        executor.executeOrder(jobId);

        vm.expectRevert(abi.encodeWithSelector(SchedulingBase.InvalidExecution.selector));
        executor.executeOrder(jobId);
        vm.stopPrank();
    }

    function test_ExecuteOrderRevertWhen_TheStartDateIsInTheFuture()
        public
        whenOrderIsEnabled
        whenTheOrderIsDue
        whenAllExecutionsHaveNotBeenCompleted
    {
        // it should revert
        uint48 _executeInterval = 1 days;
        uint16 _numberOfExecutions = 10;
        uint48 _startDate = uint48(block.timestamp + 1 days);
        Execution memory _execution =
            Execution({ target: address(0x1), value: 100, callData: bytes("") });
        bytes memory _executionData = abi.encode(_execution);
        bytes memory data =
            abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _executionData);

        vm.prank(address(target));
        executor.onInstall(data);

        uint256 jobId = 1;

        checkExecutionDataAdded(
            address(target),
            jobId,
            _executeInterval,
            _numberOfExecutions,
            _startDate,
            _executionData
        );

        vm.startPrank(address(target));
        vm.expectRevert(abi.encodeWithSelector(SchedulingBase.InvalidExecution.selector));
        executor.executeOrder(jobId);
        vm.stopPrank();
    }

    function test_ExecuteOrderWhenTheStartDateIsInThePast()
        public
        whenOrderIsEnabled
        whenTheOrderIsDue
        whenAllExecutionsHaveNotBeenCompleted
    {
        // it should make the stored transfer
        // it should update the last order timestamp
        // it should update the order execution count
        // it should emit an ExecutionTriggered event
        uint48 _executeInterval = 1 seconds;
        uint16 _numberOfExecutions = 10;
        uint48 _startDate = uint48(block.timestamp);
        Execution memory _execution =
            Execution({ target: address(0x1), value: 100, callData: bytes("") });
        bytes memory _executionData = abi.encode(_execution);
        bytes memory data =
            abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _executionData);

        vm.prank(address(target));
        executor.onInstall(data);

        uint256 jobId = 1;

        checkExecutionDataAdded(
            address(target),
            jobId,
            _executeInterval,
            _numberOfExecutions,
            _startDate,
            _executionData
        );

        vm.startPrank(address(target));
        vm.warp(block.timestamp + 1 days);
        executor.executeOrder(jobId);
        vm.stopPrank();

        uint256 value = target.value();
        assertGt(value, 0);
    }

    function test_NameShouldReturnScheduledTransfers() public {
        // it should return ScheduledTransfers
        string memory name = executor.name();
        assertEq(name, "ScheduledTransfers");
    }

    function test_VersionShouldReturn100() public {
        // it should return 1.0.0
        string memory version = executor.version();
        assertEq(version, "1.0.0");
    }

    function test_IsModuleTypeWhenTypeIDIs2() public {
        // it should return true
        bool isModuleType = executor.isModuleType(2);
        assertTrue(isModuleType);
    }

    function test_IsModuleTypeWhenTypeIDIsNot2() public {
        // it should return false
        bool isModuleType = executor.isModuleType(1);
        assertFalse(isModuleType);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenOrderIsEnabled() {
        _;
    }

    modifier whenTheOrderIsDue() {
        _;
    }

    modifier whenAllExecutionsHaveNotBeenCompleted() {
        _;
    }
}
