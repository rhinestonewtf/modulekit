// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import { RegistryHook } from "src/RegistryHook/RegistryHook.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { MockRegistry } from "test/mocks/MockRegistry.sol";

contract RegistryHookTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    RegistryHook internal hook;
    MockRegistry internal _registry;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();

        hook = new RegistryHook();
        _registry = new MockRegistry();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        bytes memory data = abi.encodePacked(address(_registry));

        hook.onInstall(data);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.AlreadyInitialized.selector, address(this))
        );
        hook.onInstall(data);
    }

    function test_OnInstallWhenModuleIsNotIntialized() public {
        // it should set the registry of msg.sender
        // it should emit RegistrySet
        bytes memory data = abi.encodePacked(address(_registry));

        vm.expectEmit(true, true, true, true, address(hook));
        emit RegistryHook.RegistrySet({ smartAccount: address(this), registry: address(_registry) });

        hook.onInstall(data);

        address registry = hook.registry(address(this));
        assertEq(registry, address(_registry));
    }

    function test_OnUninstallShouldRemoveTheRegistry() public {
        // it should remove the registry
        test_OnInstallWhenModuleIsNotIntialized();

        hook.onUninstall("");

        address registry = hook.registry(address(this));
        assertEq(registry, address(0));
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool isInitialized = hook.isInitialized(address(this));
        assertFalse(isInitialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenModuleIsNotIntialized();

        bool isInitialized = hook.isInitialized(address(this));
        assertTrue(isInitialized);
    }

    function test_SetRegistryRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        hook.setRegistry(address(_registry));
    }

    function test_SetRegistryWhenModuleIsIntialized() public {
        // it should set the registry of msg.sender
        // it should emit RegistrySet
        test_OnInstallWhenModuleIsNotIntialized();

        address newRegistry = makeAddr("newRegistry");

        vm.expectEmit(address(hook));
        emit RegistryHook.RegistrySet({ smartAccount: address(this), registry: newRegistry });

        hook.setRegistry(newRegistry);

        address registry = hook.registry(address(this));
        assertEq(registry, newRegistry);
    }

    function test_PreCheckWhenFunctionIsNotInstallModuleOrExecuteFromExecutor() public {
        // it should return
        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            bytes32(0),
            abi.encodePacked(address(1), uint256(0), "")
        );

        hook.preCheck(address(0), 0, msgData);
    }

    function test_PreCheckRevertWhen_ExecutorIsNotAttested()
        external
        whenFunctionIsExecuteFromExecutor
    {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();

        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.executeFromExecutor.selector,
            bytes32(0),
            abi.encodePacked(address(1), uint256(0), "")
        );

        vm.expectRevert();
        hook.preCheck(address(0x420), 0, msgData);
    }

    function test_PreCheckWhenExecutorIsAttested() external whenFunctionIsExecuteFromExecutor {
        // it should return
        test_OnInstallWhenModuleIsNotIntialized();

        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.executeFromExecutor.selector,
            bytes32(0),
            abi.encodePacked(address(1), uint256(0), "")
        );

        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckRevertWhen_ModuleIsNotAttested() public whenFunctionIsInstallModule {
        // it should revert
        test_OnInstallWhenModuleIsNotIntialized();

        bytes memory msgData =
            abi.encodeWithSelector(IERC7579Account.installModule.selector, 0, address(0x420), "");

        vm.expectRevert();
        hook.preCheck(address(0), 0, msgData);
    }

    function test_PreCheckWhenModuleIsAttested() public whenFunctionIsInstallModule {
        // it should return
        test_OnInstallWhenModuleIsNotIntialized();

        bytes memory msgData =
            abi.encodeWithSelector(IERC7579Account.installModule.selector, 0, address(1), "");

        hook.preCheck(address(0), 0, msgData);
    }

    function test_PostCheckShouldReturn() public {
        // it should return
        hook.postCheck("");
    }

    function test_NameShouldReturnRegistryHook() public {
        // it should return RegistryHook
        string memory name = hook.name();
        assertEq(name, "RegistryHook");
    }

    function test_VersionShouldReturn100() public {
        // it should return 1.0.0
        string memory version = hook.version();
        assertEq(version, "1.0.0");
    }

    function test_IsModuleTypeWhenTypeIDIs4() public {
        // it should return true
        bool isModuleType = hook.isModuleType(4);
        assertTrue(isModuleType);
    }

    function test_IsModuleTypeWhenTypeIDIsNot4() public {
        // it should return false
        bool isModuleType = hook.isModuleType(1);
        assertFalse(isModuleType);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenFunctionIsInstallModule() {
        _;
    }

    modifier whenFunctionIsExecuteFromExecutor() {
        _;
    }
}
