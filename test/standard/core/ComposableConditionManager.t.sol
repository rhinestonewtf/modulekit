// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import {
    ComposableConditionManager,
    ConditionConfig,
    ICondition
} from "../../../src/core/ComposableCondition.sol";
import { MockCondition } from "../../../src/test/mocks/MockCondition.sol";
import { MockRegistry } from "../../../src/test/mocks/MockRegistry.sol";
import { MerkleTreeCondition } from "../../../src/modulekit/conditions/MerkleTreeCondition.sol";

import { Merkle } from "murky/Merkle.sol";

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
    MockRegistry registry;
    MerkleTreeCondition merkleTreeCondition;

    function setUp() public {
        registry = new MockRegistry();
        conditionManager = new ComposableConditionManager(registry);
        mockCondition = new MockCondition();
        mockInvalidCondition = new MockInvalidCondition();
        merkleTreeCondition = new MerkleTreeCondition();
    }

    function test_ConditionImpl_Merkle() public {
        // prep merkle proof
        Merkle m = new Merkle();
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = bytes32("0x0");
        leaves[1] = bytes32("0x1");
        leaves[2] = bytes32("0x2");
        leaves[3] = bytes32("0x3");
        // Get Root, Proof, and Verify
        bytes32 root = m.getRoot(leaves);
        bytes32[] memory proof = m.getProof(leaves, 2); // will get proof for 0x2 value
        address executor = makeAddr("executor");
        address account = address(this);

        ConditionConfig[] memory conditions = new ConditionConfig[](1);

        conditions[0] = ConditionConfig({
            condition: merkleTreeCondition,
            conditionData: abi.encode(MerkleTreeCondition.Params({ root: root }))
        });

        conditionManager.setHash(executor, conditions);

        MerkleTreeCondition.MerkleParams memory subParams =
            MerkleTreeCondition.MerkleParams({ proof: proof, leaf: bytes32("0x2") });
        bytes[] memory subParamsBytes = new bytes[](1);
        subParamsBytes[0] = abi.encode(subParams);

        vm.startPrank(executor);
        bool result = conditionManager.checkCondition({
            account: account,
            conditions: conditions,
            subParams: subParamsBytes
        });
        vm.stopPrank();

        assertTrue(result);
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
