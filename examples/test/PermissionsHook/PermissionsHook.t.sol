// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import {
    SessionData,
    SessionKeyManagerLib
} from "@rhinestone/sessionkeymanager/src/SessionKeyManagerLib.sol";
import { MockExecutor } from "@rhinestone/modulekit/src/Mocks.sol";
import { Solarray } from "solarray/Solarray.sol";

import {
    MODULE_TYPE_HOOK, MODULE_TYPE_EXECUTOR
} from "@rhinestone/modulekit/src/external/ERC7579.sol";
import { PermissionsHook, IERC7579Account } from "src/PermissionsHook/PermissionsHook.sol";

contract PermissionsHookTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // Account instance and hook
    AccountInstance internal instance;
    PermissionsHook internal permissionsHook;

    // Mock executors
    MockExecutor internal executorDisallowed;
    MockExecutor internal executorAllowed;

    address activeExecutor;
    bool activeCallSuccess;

    function setUp() public {
        init();

        permissionsHook = new PermissionsHook();
        vm.label(address(permissionsHook), "permissionsHook");
        executorDisallowed = new MockExecutor();
        vm.label(address(executorDisallowed), "executorDisallowed");
        executorAllowed = new MockExecutor();
        vm.label(address(executorAllowed), "executorAllowed");

        instance = makeAccountInstance("PermissionsHookTestAccount");
        deal(address(instance.account), 100 ether);

        setUpPermissionsHook();
    }

    function setUpPermissionsHook() internal {
        console2.log("setting up permissions hook");
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executorDisallowed),
            data: ""
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executorAllowed),
            data: ""
        });

        address[] memory modules = new address[](3);
        modules[0] = address(executorDisallowed);
        modules[1] = address(executorAllowed);
        modules[2] = address(instance.defaultValidator);

        PermissionsHook.ModulePermissions[] memory permissions =
            new PermissionsHook.ModulePermissions[](3);
        permissions[0] = PermissionsHook.ModulePermissions({
            selfCall: false,
            moduleCall: false,
            hasAllowedTargets: true,
            sendValue: false,
            hasAllowedFunctions: true,
            erc20Transfer: false,
            erc721Transfer: false,
            moduleConfig: false,
            allowedFunctions: new bytes4[](0),
            allowedTargets: new address[](0)
        });

        permissions[1] = PermissionsHook.ModulePermissions({
            selfCall: true,
            moduleCall: true,
            hasAllowedTargets: false,
            sendValue: true,
            hasAllowedFunctions: false,
            erc20Transfer: true,
            erc721Transfer: true,
            moduleConfig: true,
            allowedFunctions: new bytes4[](0),
            allowedTargets: new address[](0)
        });

        permissions[2] = PermissionsHook.ModulePermissions({
            selfCall: true,
            moduleCall: true,
            hasAllowedTargets: false,
            sendValue: true,
            hasAllowedFunctions: false,
            erc20Transfer: true,
            erc721Transfer: true,
            moduleConfig: true,
            allowedFunctions: new bytes4[](0),
            allowedTargets: new address[](0)
        });

        console2.log("installing module");
        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(permissionsHook),
            data: abi.encode(modules, permissions)
        });
        console2.log("installed");
    }

    modifier performWithBothExecutors() {
        // Disallowed executor
        activeExecutor = address(executorDisallowed);
        _;
        assertFalse(activeCallSuccess);

        // Allowed executor
        activeExecutor = address(executorAllowed);
        _;
        assertTrue(activeCallSuccess);
    }

    function test_selfCall() public performWithBothExecutors {
        address target = instance.account;
        uint256 value = 0;
        bytes memory callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            bytes32(0),
            abi.encodePacked(makeAddr("target"), uint256(1 ether), bytes(""))
        );

        bytes memory executorCallData = abi.encodeWithSelector(
            MockExecutor.exec.selector, instance.account, target, value, callData
        );

        (bool success, bytes memory result) = activeExecutor.call(executorCallData);
        activeCallSuccess = success;
    }

    function test_sendValue() public performWithBothExecutors {
        address target = makeAddr("target");
        uint256 value = 1 ether;
        bytes memory callData = "";

        bytes memory executorCallData = abi.encodeWithSelector(
            MockExecutor.exec.selector, instance.account, target, value, callData
        );

        (bool success, bytes memory result) = activeExecutor.call(executorCallData);
        activeCallSuccess = success;
    }

    function test_sendValue_4337() public performWithBothExecutors {
        address target = makeAddr("target");
        uint256 balanceBefore = target.balance;
        uint256 value = 1 ether;
        bytes memory callData = "";

        instance.exec({ target: address(target), value: value, callData: callData });
        assertEq(target.balance, balanceBefore + value);
    }
}
