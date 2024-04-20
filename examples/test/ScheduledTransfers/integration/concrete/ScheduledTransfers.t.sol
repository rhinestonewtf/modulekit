// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp
} from "test/BaseIntegration.t.sol";
import { ScheduledTransfers, SchedulingBase } from "src/ScheduledTransfers/ScheduledTransfers.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/src/external/ERC7579.sol";
import { Execution } from "modulekit/src/external/ERC7579.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract ScheduledTransfersIntegrationTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ScheduledTransfers internal executor;
    MockERC20 internal token;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address _target;
    bytes _executionData;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseIntegrationTest.setUp();

        executor = new ScheduledTransfers();

        _target = makeAddr("target");

        token = new MockERC20("USDC", "USDC", 18);
        vm.label(address(token), "USDC");
        token.mint(address(instance.account), 1_000_000);

        vm.warp(1_713_357_071);

        uint48 _executeInterval = 1 days;
        uint16 _numberOfExecutions = 10;
        uint48 _startDate = uint48(block.timestamp);
        _executionData = abi.encode(address(_target), address(0), uint256(10));

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _executionData)
        });
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

    function test_OnInstallAddExecution() public {
        // it should add an execution
        checkExecutionDataAdded(
            address(instance.account), 1, 1 days, 10, uint48(block.timestamp), _executionData
        );
    }

    function test_OnUninstallRemoveExecutions() public {
        // it should remove the execution
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: ""
        });

        (
            uint48 executeInterval,
            uint16 numberOfExecutions,
            uint16 numberOfExecutionsCompleted,
            uint48 startDate,
            bool isEnabled,
            uint48 lastExecutionTime,
            bytes memory executionData
        ) = executor.executionLog(address(instance.account), 1);
        assertEq(executeInterval, 0);
        assertEq(numberOfExecutions, 0);
        assertEq(startDate, 0);
        assertEq(isEnabled, false);
        assertEq(lastExecutionTime, 0);
        assertEq(numberOfExecutionsCompleted, 0);
        assertEq(executionData, "");
    }

    function test_AddOrder() public {
        // it should add an execution
        uint48 _executeInterval = 2 days;
        uint16 _numberOfExecutions = 5;
        uint48 _startDate = uint48(block.timestamp);
        bytes memory _newExecutionData = abi.encode(address(2), address(0), uint256(100));

        instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(
                SchedulingBase.addOrder.selector,
                abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _newExecutionData)
            ),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        checkExecutionDataAdded(
            address(instance.account),
            2,
            _executeInterval,
            _numberOfExecutions,
            _startDate,
            _newExecutionData
        );
    }

    function test_ToggleOrder() public {
        // it should toggle the execution
        uint256 jobId = 1;

        instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(SchedulingBase.toggleOrder.selector, jobId),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        (,,,, bool isEnabled,,) = executor.executionLog(address(instance.account), jobId);
        assertFalse(isEnabled);
    }

    function test_ExecuteOrder_WhenNativeTransfer() public {
        // it should execute the transfer
        uint256 jobId = 1;

        instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(SchedulingBase.executeOrder.selector, jobId),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        (,, uint16 numberOfExecutionsCompleted,,, uint48 lastExecutionTime,) =
            executor.executionLog(address(instance.account), jobId);
        assertEq(lastExecutionTime, block.timestamp);
        assertEq(numberOfExecutionsCompleted, 1);

        assertEq(_target.balance, 10);
    }

    function test_ExecuteOrder_WhenERC20Transfer() public {
        // it should schedule and execute the transfer
        uint48 _executeInterval = 2 days;
        uint16 _numberOfExecutions = 5;
        uint48 _startDate = uint48(block.timestamp);
        bytes memory _newExecutionData = abi.encode(address(_target), address(token), uint256(10));

        instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(
                SchedulingBase.addOrder.selector,
                abi.encodePacked(_executeInterval, _numberOfExecutions, _startDate, _newExecutionData)
            ),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        uint256 jobId = 2;

        checkExecutionDataAdded(
            address(instance.account),
            jobId,
            _executeInterval,
            _numberOfExecutions,
            _startDate,
            _newExecutionData
        );

        instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(SchedulingBase.executeOrder.selector, jobId),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        (,, uint16 numberOfExecutionsCompleted,,, uint48 lastExecutionTime,) =
            executor.executionLog(address(instance.account), jobId);
        assertEq(lastExecutionTime, block.timestamp);
        assertEq(numberOfExecutionsCompleted, 1);

        assertEq(token.balanceOf(_target), 10);
    }
}
