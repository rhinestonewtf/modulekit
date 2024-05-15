// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp
} from "test/BaseIntegration.t.sol";
import { OwnableExecutor } from "src/OwnableExecutor/OwnableExecutor.sol";
import {
    MODULE_TYPE_EXECUTOR,
    Execution,
    ERC7579ExecutionLib
} from "modulekit/src/external/ERC7579.sol";
import { SENTINEL } from "sentinellist/SentinelList.sol";

contract OwnableExecutorIntegrationTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    OwnableExecutor internal executor;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address target;
    address[] _owners;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseIntegrationTest.setUp();

        executor = new OwnableExecutor();
        target = makeAddr("target");

        _owners = new address[](2);
        _owners[0] = makeAddr("owner1");
        _owners[1] = makeAddr("owner2");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: abi.encodePacked(_owners[0])
        });

        address[] memory owners = executor.getOwners(address(instance.account));
        assertEq(owners.length, 1);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallSetsOwner() public {
        // it should set the owner of the account
        bool isInitialized = executor.isInitialized(address(instance.account));
        assertTrue(isInitialized);

        address[] memory owners = executor.getOwners(address(instance.account));
        assertEq(owners.length, 1);
    }

    function test_OnUninstallRemovesOwners() public {
        // it should remove the owners of the account
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: ""
        });

        bool isInitialized = executor.isInitialized(address(instance.account));
        assertFalse(isInitialized);

        uint256 ownerCount = executor.ownerCount(address(instance.account));
        assertEq(ownerCount, 0);
    }

    function test_AddOwner() public {
        // it should add an owner to the account
        instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(OwnableExecutor.addOwner.selector, _owners[1]),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory owners = executor.getOwners(address(instance.account));
        assertEq(owners.length, 2);
    }

    function test_RemoveOwner() public {
        // it should remove an owner from the account
        instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(OwnableExecutor.addOwner.selector, _owners[1]),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory owners = executor.getOwners(address(instance.account));
        assertEq(owners.length, 2);

        instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(OwnableExecutor.removeOwner.selector, SENTINEL, _owners[1]),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        owners = executor.getOwners(address(instance.account));
        assertEq(owners.length, 1);

        instance.getExecOps({
            target: address(executor),
            value: 0,
            callData: abi.encodeWithSelector(OwnableExecutor.removeOwner.selector, SENTINEL, _owners[0]),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        uint256 ownerCount = executor.ownerCount(address(instance.account));
        assertEq(ownerCount, 0);
    }

    function test_ExecuteOnOwnedAccount() public {
        // it should execute a transaction on the account
        uint256 value = 1 ether;
        uint256 prevBalance = target.balance;

        vm.prank(_owners[0]);
        executor.executeOnOwnedAccount(
            address(instance.account), abi.encodePacked(target, value, bytes(""))
        );

        assertEq(target.balance, prevBalance + value);
    }

    function test_ExecuteOnOwnedAccount_RevertWhen_UnauthorizedOwner() public {
        // it should execute a transaction on the account
        uint256 value = 1 ether;
        uint256 prevBalance = target.balance;

        vm.prank(_owners[1]);
        vm.expectRevert(OwnableExecutor.UnauthorizedAccess.selector);

        executor.executeOnOwnedAccount(
            address(instance.account), abi.encodePacked(target, value, bytes(""))
        );
    }

    function test_ExecuteBatchOnOwnedAccount() public {
        // it should execute a transaction on the account
        address target2 = makeAddr("target2");

        uint256 value = 1 ether;

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: target, value: value, callData: bytes("") });
        executions[1] = Execution({ target: target2, value: value, callData: bytes("") });

        uint256 prevBalanceTarget1 = target.balance;
        uint256 prevBalanceTarget2 = target2.balance;

        vm.prank(_owners[0]);
        executor.executeBatchOnOwnedAccount(
            address(instance.account), ERC7579ExecutionLib.encodeBatch(executions)
        );

        assertEq(target.balance, prevBalanceTarget1 + value);
        assertEq(target2.balance, prevBalanceTarget2 + value);
    }

    function test_ExecuteBatchOnOwnedAccount_RevertWhen_UnauthorizedOwner() public {
        // it should execute a transaction on the account
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: target, value: 1 ether, callData: bytes("") });

        vm.prank(_owners[1]);
        vm.expectRevert(OwnableExecutor.UnauthorizedAccess.selector);

        executor.executeBatchOnOwnedAccount(
            address(instance.account), ERC7579ExecutionLib.encodeBatch(executions)
        );
    }
}
