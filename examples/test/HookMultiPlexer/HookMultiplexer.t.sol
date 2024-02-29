// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import {
    SessionData,
    SessionKeyManagerLib
} from "@rhinestone/sessionkeymanager/src/SessionKeyManagerLib.sol";
import { MockExecutor, MockERC20 } from "@rhinestone/modulekit/src/Mocks.sol";
import { Solarray } from "solarray/Solarray.sol";

import {
    MODULE_TYPE_HOOK, MODULE_TYPE_EXECUTOR
} from "@rhinestone/modulekit/src/external/ERC7579.sol";
import { IHookMultiPlexer, HookMultiPlexer, hookFlag } from "src/HookMultiPlex/HookMultiPlexer.sol";

import { PermissionFlags } from "src/HookMultiPlex/subHooks/PermissionFlags.sol";
import { SpendingLimits } from "src/HookMultiPlex/subHooks/SpendingLimits.sol";

contract HookMultiPlexerTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // Account instance and hook
    AccountInstance internal instance;
    MockERC20 internal token;
    HookMultiPlexer internal multiplexer;
    PermissionFlags internal permissionFlagsSubHook;
    SpendingLimits internal spendingLimitsSubHook;

    // Mock executors
    MockExecutor internal executorDisallowed;
    MockExecutor internal executorAllowed;

    address activeExecutor;
    bool activeCallSuccess;

    function setUp() public {
        init();

        multiplexer = new HookMultiPlexer();
        vm.label(address(multiplexer), "multiplexer");

        permissionFlagsSubHook = new PermissionFlags(address(multiplexer));
        vm.label(address(permissionFlagsSubHook), "SubHook:PermissionFlags");
        spendingLimitsSubHook = new SpendingLimits(address(multiplexer));
        vm.label(address(spendingLimitsSubHook), "SubHook:SpendingLimits");

        executorDisallowed = new MockExecutor();
        vm.label(address(executorDisallowed), "executorDisallowed");
        executorAllowed = new MockExecutor();
        vm.label(address(executorAllowed), "executorAllowed");

        instance = makeAccountInstance("PermissionsHookTestAccount");
        deal(address(instance.account), 100 ether);

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);

        setupMultiplexer();
        setUpPermissionsSubHook();
        setupSpendingLimitsSubHook();
    }

    function setupMultiplexer() internal {
        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(multiplexer),
            data: ""
        });

        vm.prank(instance.account);

        IHookMultiPlexer.ConfigParam[] memory globalHooksConfig =
            new IHookMultiPlexer.ConfigParam[](2);
        globalHooksConfig[0] = IHookMultiPlexer.ConfigParam({
            hook: address(permissionFlagsSubHook),
            isExecutorHook: hookFlag.wrap(false),
            isValidatorHook: hookFlag.wrap(true),
            isConfigHook: hookFlag.wrap(false)
        });

        globalHooksConfig[1] = IHookMultiPlexer.ConfigParam({
            hook: address(spendingLimitsSubHook),
            isExecutorHook: hookFlag.wrap(false),
            isValidatorHook: hookFlag.wrap(true),
            isConfigHook: hookFlag.wrap(false)
        });

        multiplexer.installGlobalHooks(globalHooksConfig);
    }

    function setUpPermissionsSubHook() internal {
        PermissionFlags.AccessFlags memory flags = PermissionFlags.AccessFlags({
            selfCall: false,
            moduleCall: false,
            hasAllowedTargets: true,
            sendValue: false,
            hasAllowedFunctions: true,
            erc20Transfer: true,
            erc721Transfer: false,
            moduleConfig: false
        });

        vm.prank(instance.account);
        permissionFlagsSubHook.configure({
            module: address(instance.defaultValidator),
            flags: flags,
            allowedTargets: new address[](0),
            allowedFunctions: new bytes4[](0)
        });
    }

    function setupSpendingLimitsSubHook() public {
        vm.prank(instance.account);
        spendingLimitsSubHook.configure(address(token), 500);
    }

    function test_sendERC20() public {
        address receiver = makeAddr("receiver");
        vm.prank(instance.account);
        bytes memory callData = abi.encodeCall(IERC20.transfer, (receiver, 150));

        instance.exec({ target: address(token), value: 0, callData: callData });

        assertEq(token.balanceOf(receiver), 150);
        callData = abi.encodeCall(IERC20.transfer, (receiver, 500));
        vm.expectRevert();
        instance.exec({ target: address(token), value: 0, callData: callData });
    }
}
