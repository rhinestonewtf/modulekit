// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp
} from "test/BaseIntegration.t.sol";
import { RegistryHook } from "src/RegistryHook/RegistryHook.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import {
    MODULE_TYPE_HOOK,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR
} from "modulekit/src/external/ERC7579.sol";
import { ModeCode } from "erc7579/lib/ModeLib.sol";
import { MockRegistry } from "test/mocks/MockRegistry.sol";
import { MockModule } from "test/mocks/MockModule.sol";

contract RegistryHookIntegrationTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    RegistryHook internal hook;
    MockRegistry internal registry;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address mockModule;
    address mockModuleRevoked;
    address mockModuleCode;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseIntegrationTest.setUp();

        registry = new MockRegistry();
        hook = new RegistryHook();

        mockModuleCode = address(new MockModule());

        mockModule = makeAddr("mockModule");
        vm.etch(mockModule, mockModuleCode.code);

        mockModuleRevoked = address(0x420);
        vm.etch(mockModuleRevoked, mockModuleCode.code);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hook),
            data: abi.encodePacked(address(registry))
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallSetRegistry() public {
        // it should set the registry of account
        address registry = hook.registry(address(instance.account));
        assertEq(registry, address(registry));
    }

    function test_OnUninstallRemoveRegistry() public {
        // it should remove the registry
        instance.uninstallModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(hook), data: "" });

        address registry = hook.registry(address(instance.account));
        assertEq(registry, address(0));
    }

    function test_SetRegistry() public {
        // it should set the registry of account
        address newRegistry = makeAddr("newRegistry");

        instance.getExecOps({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(RegistryHook.setRegistry.selector, newRegistry),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address registry = hook.registry(address(instance.account));
        assertEq(registry, newRegistry);
    }

    function test_InstallModule() public {
        // it should query the registry
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(mockModule),
            data: ""
        });
    }

    function test_InstallModule_RevertWhen_RegistryReverts() public {
        // it should query the registry
        instance.expect4337Revert();

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(mockModuleRevoked),
            data: ""
        });
    }

    function testExecuteFromExecutor() public {
        // it should query the registry
        address module = makeAddr("module");
        vm.etch(module, mockModuleCode.code);

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: module, data: "" });

        vm.prank(module);
        IERC7579Account(address(instance.account)).executeFromExecutor(
            ModeCode.wrap(bytes32(0)), abi.encodePacked(address(1), uint256(0), "")
        );
    }

    function testExecuteFromExecutor_RevertWhen_RegistryReverts() public {
        // it should query the registry
        instance.uninstallModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(hook), data: "" });

        address module = address(0x420);
        vm.etch(module, mockModuleCode.code);

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: module, data: "" });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hook),
            data: abi.encodePacked(address(registry))
        });

        vm.prank(module);
        vm.expectRevert();
        IERC7579Account(address(instance.account)).executeFromExecutor(
            ModeCode.wrap(bytes32(0)), abi.encodePacked(address(1), uint256(0), "")
        );
    }
}
