// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import { SSTORE2 } from "solady/src/utils/SSTORE2.sol";
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

import {
    PermissionHook,
    PermissionFlags,
    PermissionFlagsLib
} from "src/HookMultiPlex/subHooks/PermissionFlags.sol";
import { SpendingLimits } from "src/HookMultiPlex/subHooks/SpendingLimits.sol";

contract HookMultiPlexerTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // Account instance and hook
    AccountInstance internal instance;
    MockERC20 internal token;
    HookMultiPlexer internal multiplexer;
    PermissionHook internal permissionFlagsSubHook;
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

        permissionFlagsSubHook = new PermissionHook(address(multiplexer));
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
        // PermissionFlags.PermissionFlags memory flags = PermissionFlags.PermissionFlags({
        //     selfCall: false,
        //     moduleCall: false,
        //     hasAllowedTargets: true,
        //     sendValue: false,
        //     hasAllowedFunctions: true,
        //     erc20Transfer: true,
        //     erc721Transfer: false,
        //     moduleConfig: false
        // });

        PermissionFlags flags = PermissionFlagsLib.pack({
            permit_selfCall: false,
            permit_moduleCall: false,
            permit_hasAllowedTargets: true,
            permit_sendValue: false,
            permit_hasAllowedFunctions: true,
            permit_erc20Transfer: true,
            permit_erc721Transfer: false,
            permit_moduleConfig: false
        });

        flags = PermissionFlags.wrap(bytes32(uint256(type(uint256).max)));

        // vm.prank(instance.account);
        // permissionFlagsSubHook.configure({
        //     module: address(instance.defaultValidator),
        //     flags: flags,
        //     allowedTargets: new address[](0),
        //     allowedFunctions: new bytes4[](0)
        // });

        address[] memory allowedTargets = new address[](1);
        allowedTargets[0] = address(0x414141414141);
        // allowedTargets[1] = address(0x414141414141);
        bytes4[] memory allowedFunctions = new bytes4[](1);
        allowedFunctions[0] = IERC20.transfer.selector;
        PermissionHook.ConfigParams memory params = PermissionHook.ConfigParams({
            flags: flags,
            allowedTargets: allowedTargets,
            allowedFunctions: allowedFunctions
        });

        bytes memory data = abi.encode(params);

        address pointer = SSTORE2.write(data);

        vm.prank(instance.account);
        permissionFlagsSubHook.configureWithRegistry(address(instance.defaultValidator), pointer);
        permissionFlagsSubHook.configure(address(instance.defaultValidator), params);

        PermissionHook.ConfigParams memory _params = permissionFlagsSubHook.getPermissions(
            instance.account, address(instance.defaultValidator)
        );
        assertEq(PermissionFlags.unwrap(params.flags), PermissionFlags.unwrap(_params.flags));

        console2.log("pointer", pointer);
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
