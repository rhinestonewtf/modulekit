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
import { MockRegistry } from "test/mocks/MockRegistry.sol";
import { MODULE_TYPE_HOOK, MODULE_TYPE_VALIDATOR } from "modulekit/src/external/ERC7579.sol";

contract RegistryHookIntegrationTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    RegistryHook internal hook;
    MockRegistry internal _registry;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address mockModule;
    address mockModuleRevoked;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseIntegrationTest.setUp();

        hook = new RegistryHook();
        _registry = new MockRegistry();

        mockModule = makeAddr("mockModule");
        vm.etch(mockModule, hex"00");

        mockModuleRevoked = address(0x420);
        vm.etch(mockModuleRevoked, hex"00");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hook),
            data: abi.encodePacked(address(_registry))
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallSetRegistry() public {
        // it should set the registry of account
        address registry = hook.registry(address(instance.account));
        assertEq(registry, address(_registry));
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
}
