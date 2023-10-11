// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import {
    ComposableConditionManager,
    ConditionConfig,
    ICondition
} from "../../src/core/ComposableCondition.sol";

contract MockCondition is ICondition {
    function checkCondition(
        address account,
        address executor,
        bytes calldata boundries
    )
        external
        view
        returns (bool)
    {
        return true;
    }
}

contract ComposableConditionManagerTest is Test {
    ComposableConditionManager conditionManager;
    MockCondition mockCondition;

    function setUp() public {
        conditionManager = new ComposableConditionManager();
        mockCondition = new MockCondition();
    }

    function testCheckCondition() public {
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] = ConditionConfig({ boundriesData: bytes(""), condition: mockCondition });

        conditionManager.setHash(executor, conditions);

        vm.startPrank(executor);
        bool result = conditionManager.checkCondition(account, conditions);
        vm.stopPrank();

        assertTrue(result);
    }

    function testCheckCondition__RevertWhen__NoHash() public {
        address condition = makeAddr("condition");
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ boundriesData: bytes(""), condition: ICondition(condition) });

        vm.startPrank(executor);
        vm.expectRevert();
        conditionManager.checkCondition(account, conditions);
        vm.stopPrank();
    }

    function testCheckCondition__RevertWhen__NoConditionsProvided() public {
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](0);

        vm.startPrank(executor);
        vm.expectRevert();
        conditionManager.checkCondition(account, conditions);
        vm.stopPrank();
    }

    function testCheckCondition__RevertWhen__InvalidHash() public {
        address condition = makeAddr("condition");
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ boundriesData: bytes(""), condition: ICondition(condition) });

        conditionManager.setHash(executor, conditions);

        ConditionConfig[] memory newConditions = new ConditionConfig[](2);
        newConditions[0] =
            ConditionConfig({ boundriesData: bytes(""), condition: ICondition(condition) });
        newConditions[1] =
            ConditionConfig({ boundriesData: bytes(""), condition: ICondition(condition) });

        vm.startPrank(executor);
        vm.expectRevert();
        conditionManager.checkCondition(account, newConditions);
        vm.stopPrank();
    }

    function testCheckCondition__RevertWhen__ConditionNotMet() public {
        address condition = makeAddr("condition");
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ boundriesData: bytes(""), condition: ICondition(condition) });

        conditionManager.setHash(executor, conditions);

        vm.startPrank(executor);
        vm.expectRevert();
        conditionManager.checkCondition(account, conditions);
        vm.stopPrank();
    }

    function testConditionDigest() public {
        address condition = makeAddr("condition");
        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ boundriesData: bytes(""), condition: ICondition(condition) });

        bytes32 digest = conditionManager._conditionDigest(conditions);

        assertEq(digest, keccak256(abi.encode(conditions)));
    }

    function testSetAndGetHash() public {
        address condition = makeAddr("condition");
        address executor = makeAddr("executor");
        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] =
            ConditionConfig({ boundriesData: bytes(""), condition: ICondition(condition) });
        bytes32 digest = conditionManager._conditionDigest(conditions);

        conditionManager.setHash(executor, conditions);

        bytes32 storedDigest = conditionManager.getHash(address(this), executor);
        assertEq(digest, storedDigest);
    }
}
