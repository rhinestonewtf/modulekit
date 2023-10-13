// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import {
    ComposableConditionManager,
    ConditionConfig,
    ICondition
} from "../../src/core/ComposableCondition.sol";
import { MockCondition } from "../../src/test/mocks/MockCondition.sol";

contract MockInvalidCondition is ICondition {
    function checkCondition(
        address account,
        address executor,
        bytes calldata conditionData,
        bytes calldata subData
    )
        external
        view
        returns (bool)
    {
        return false;
    }
}

contract ComposableConditionManagerTest is Test {
    ComposableConditionManager conditionManager;
    MockCondition mockCondition;
    MockInvalidCondition mockInvalidCondition;

    function setUp() public {
        conditionManager = new ComposableConditionManager();
        mockCondition = new MockCondition();
        mockInvalidCondition = new MockInvalidCondition();
    }

    function testCheckCondition() public {
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);

        conditions[0] = ConditionConfig({ condition: mockCondition, conditionData: bytes("") });

        conditionManager.setHash(executor, conditions);

        vm.startPrank(executor);
        bool result = conditionManager.checkCondition(account, conditions);
        vm.stopPrank();

        assertTrue(result);
    }

    function testCheckCondition__RevertWhen__NoConditionsProvided() public {
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](0);

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ComposableConditionManager.InvalidConditionsProvided.selector, bytes32(0)
            )
        );
        conditionManager.checkCondition(account, conditions);
        vm.stopPrank();
    }

    function testCheckCondition__RevertWhen__NoHash() public {
        address condition = makeAddr("condition");
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ComposableConditionManager.InvalidConditionsProvided.selector, bytes32(0)
            )
        );
        conditionManager.checkCondition(account, conditions);
        vm.stopPrank();
    }

    function testCheckCondition__RevertWhen__InvalidHash() public {
        address condition = makeAddr("condition");
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });

        conditionManager.setHash(executor, conditions);

        ConditionConfig[] memory newConditions = new ConditionConfig[](2);
        newConditions[0] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });
        newConditions[1] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });

        bytes32 digest = conditionManager._conditionDigest(newConditions);

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ComposableConditionManager.InvalidConditionsProvided.selector, digest
            )
        );
        conditionManager.checkCondition(account, newConditions);
        vm.stopPrank();
    }

    function testCheckCondition__RevertWhen__ConditionNotMet() public {
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ condition: mockInvalidCondition, conditionData: bytes("") });

        conditionManager.setHash(executor, conditions);

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ComposableConditionManager.ConditionNotMet.selector,
                account,
                executor,
                mockInvalidCondition
            )
        );
        conditionManager.checkCondition(account, conditions);
        vm.stopPrank();
    }

    function testCheckConditionWithSubParams() public {
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);

        conditions[0] = ConditionConfig({ condition: mockCondition, conditionData: bytes("") });

        conditionManager.setHash(executor, conditions);

        bytes[] memory subParams = new bytes[](1);
        subParams[0] = bytes("subParams");

        vm.startPrank(executor);
        bool result = conditionManager.checkCondition(account, conditions, subParams);
        vm.stopPrank();

        assertTrue(result);
    }

    function testCheckConditionWithSubParams__RevertWhen__NoConditionsProvided() public {
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](0);

        bytes[] memory subParams = new bytes[](0);

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ComposableConditionManager.InvalidConditionsProvided.selector, bytes32(0)
            )
        );
        conditionManager.checkCondition(account, conditions, subParams);
        vm.stopPrank();
    }

    function testCheckConditionWithSubParams__RevertWhen__NoHash() public {
        address condition = makeAddr("condition");
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });

        bytes[] memory subParams = new bytes[](1);
        subParams[0] = bytes("subParams");

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ComposableConditionManager.InvalidConditionsProvided.selector, bytes32(0)
            )
        );
        conditionManager.checkCondition(account, conditions, subParams);
        vm.stopPrank();
    }

    function testCheckConditionWithSubParams__RevertWhen__InvalidHash() public {
        address condition = makeAddr("condition");
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });

        conditionManager.setHash(executor, conditions);

        ConditionConfig[] memory newConditions = new ConditionConfig[](2);
        newConditions[0] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });
        newConditions[1] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });

        bytes32 digest = conditionManager._conditionDigest(newConditions);

        bytes[] memory subParams = new bytes[](2);
        subParams[0] = bytes("subParams");
        subParams[1] = bytes("subParams");

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ComposableConditionManager.InvalidConditionsProvided.selector, digest
            )
        );
        conditionManager.checkCondition(account, newConditions, subParams);
        vm.stopPrank();
    }

    function testCheckConditionWithSubParams__RevertWhen__ConditionNotMet() public {
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ condition: mockInvalidCondition, conditionData: bytes("") });

        conditionManager.setHash(executor, conditions);

        bytes[] memory subParams = new bytes[](1);
        subParams[0] = bytes("subParams");

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ComposableConditionManager.ConditionNotMet.selector,
                account,
                executor,
                mockInvalidCondition
            )
        );
        conditionManager.checkCondition(account, conditions, subParams);
        vm.stopPrank();
    }

    function testCheckConditionWithSubParams__RevertWhen__InvalidSubParamsLength() public {
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);

        conditions[0] = ConditionConfig({ condition: mockCondition, conditionData: bytes("") });

        conditionManager.setHash(executor, conditions);

        bytes[] memory subParams = new bytes[](0);

        vm.startPrank(executor);
        vm.expectRevert(
            abi.encodeWithSelector(
                ComposableConditionManager.InvalidConditionsProvided.selector, bytes32(0)
            )
        );
        conditionManager.checkCondition(account, conditions, subParams);
        vm.stopPrank();
    }

    function testConditionDigest() public {
        address condition = makeAddr("condition");
        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });

        bytes32 digest = conditionManager._conditionDigest(conditions);

        assertEq(digest, keccak256(abi.encode(conditions)));
    }

    function testSetAndGetHash() public {
        address condition = makeAddr("condition");
        address executor = makeAddr("executor");
        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ condition: ICondition(condition), conditionData: bytes("") });
        bytes32 digest = conditionManager._conditionDigest(conditions);

        conditionManager.setHash(executor, conditions);

        bytes32 storedDigest = conditionManager.getHash(address(this), executor);
        assertEq(digest, storedDigest);
    }
}
