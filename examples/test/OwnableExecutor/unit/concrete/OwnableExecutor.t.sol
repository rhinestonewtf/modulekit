// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import { OwnableExecutor } from "src/OwnableExecutor/OwnableExecutor.sol";
import { IERC7579Module } from "modulekit/src/external/ERC7579.sol";
import { MockTarget } from "test/mocks/MockTarget.sol";
import { SENTINEL } from "sentinellist/SentinelList.sol";

contract OwnableExecutorTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    OwnableExecutor internal executor;
    MockTarget internal target;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address[] _owners;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();
        executor = new OwnableExecutor();
        target = new MockTarget();

        _owners = new address[](2);

        (address _owner1,) = makeAddrAndKey("owner1");
        _owners[0] = _owner1;

        (address _owner2,) = makeAddrAndKey("owner2");
        _owners[1] = _owner2;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        bytes memory data = abi.encodePacked(_owners[0]);

        executor.onInstall(data);

        vm.expectRevert();
        executor.onInstall(data);
    }

    function test_OnInstallWhenModuleIsNotIntialized() public {
        // it should set the owner count
        // it should set the owner of the subaccount
        bytes memory data = abi.encodePacked(_owners[0]);

        executor.onInstall(data);

        address[] memory owners = executor.getOwners(address(this));
        assertEq(owners.length, 1);

        uint256 ownerCount = executor.ownerCount(address(this));
        assertEq(ownerCount, 1);
    }

    function test_OnUninstallShouldRemoveAllOwners() public {
        // it should remove the owner count
        // it should remove all owners
        test_OnInstallWhenModuleIsNotIntialized();

        executor.onUninstall("");

        uint256 ownerCount = executor.ownerCount(address(this));
        assertEq(ownerCount, 0);
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

    function test_AddOwnerRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        executor.addOwner(_owners[0]);
    }

    function test_AddOwnerRevertWhen_OwnerIs0Address() public whenModuleIsIntialized {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();

        address owner = address(0);
        vm.expectRevert(abi.encodeWithSelector(OwnableExecutor.InvalidOwner.selector, owner));
        executor.addOwner(owner);
    }

    function test_AddOwnerRevertWhen_OwnerIsAlreadyAdded() public whenModuleIsIntialized {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();

        address owner = _owners[0];
        vm.expectRevert();
        executor.addOwner(owner);
    }

    function test_AddOwnerWhenOwnerIsNotAdded() public whenModuleIsIntialized {
        // it should increment the owner count
        // it should add the owner
        test_OnInstallWhenModuleIsNotIntialized();

        address owner = _owners[1];
        executor.addOwner(owner);

        uint256 ownerCount = executor.ownerCount(address(this));
        assertEq(ownerCount, 2);
    }

    function test_RemoveOwnerRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert();
        executor.removeOwner(_owners[0], _owners[1]);
    }

    function test_RemoveOwnerWhenModuleIsIntialized() public {
        // it should decrement the owner count
        // it should remove the owner
        test_AddOwnerWhenOwnerIsNotAdded();

        executor.removeOwner(SENTINEL, _owners[1]);

        address[] memory owners = executor.getOwners(address(this));
        assertEq(owners.length, 1);

        uint256 ownerCount = executor.ownerCount(address(this));
        assertEq(ownerCount, 1);
    }

    function test_GetOwnersShouldGetAllOwners() public {
        // it should get all owners
        test_AddOwnerWhenOwnerIsNotAdded();

        address[] memory owners = executor.getOwners(address(this));
        assertEq(owners.length, 2);
        assertEq(owners[0], _owners[1]);
        assertEq(owners[1], _owners[0]);
    }

    function test_ExecuteOnOwnedAccountRevertWhen_MsgSenderIsNotAnOwner() public {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();

        vm.expectRevert(OwnableExecutor.UnauthorizedAccess.selector);
        executor.executeOnOwnedAccount(address(1), "");
    }

    function test_ExecuteOnOwnedAccountWhenMsgSenderIsAnOwner() public {
        // it should execute the calldata on the owned account
        address owner = _owners[0];
        bytes memory data = abi.encodePacked(owner);

        address ownedAccount = address(target);

        vm.prank(ownedAccount);
        executor.onInstall(data);

        address[] memory owners = executor.getOwners(ownedAccount);
        assertEq(owners.length, 1);
        assertEq(owners[0], owner);

        uint256 _value = 24;

        vm.prank(address(owner));
        executor.executeOnOwnedAccount(ownedAccount, abi.encodePacked(_value));

        uint256 value = target.value();
        assertEq(value, _value);
    }

    function test_ExecuteBatchOnOwnedAccountRevertWhen_MsgSenderIsNotAnOwner() public {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();

        vm.expectRevert(OwnableExecutor.UnauthorizedAccess.selector);
        executor.executeBatchOnOwnedAccount(address(1), "");
    }

    function test_ExecuteBatchOnOwnedAccountWhenMsgSenderIsAnOwner() public {
        // it should execute the calldata on the owned account
        address owner = _owners[0];
        bytes memory data = abi.encodePacked(owner);

        address ownedAccount = address(target);

        vm.prank(ownedAccount);
        executor.onInstall(data);

        address[] memory owners = executor.getOwners(ownedAccount);
        assertEq(owners.length, 1);
        assertEq(owners[0], owner);

        uint256 _value = 24;

        vm.prank(address(owner));
        executor.executeBatchOnOwnedAccount(ownedAccount, abi.encodePacked(_value));

        uint256 value = target.value();
        assertEq(value, _value);
    }

    function test_NameShouldReturnOwnableExecutor() public {
        // it should return OwnableExecutor
        string memory name = executor.name();
        assertEq(name, "OwnableExecutor");
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

    modifier whenModuleIsIntialized() {
        _;
    }
}
