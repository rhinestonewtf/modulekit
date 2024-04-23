// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.t.sol";
// import "src/lib/ModeLib.sol";
import { ModuleManager } from "src/core/ModuleManager.sol";

import { CALLTYPE_SINGLE, CALLTYPE_BATCH, CALLTYPE_DELEGATECALL } from "erc7579/lib/ModeLib.sol";

contract ModuleManagementTest is BaseTest {
    bytes _data;

    function setUp() public virtual override {
        super.setUp();
    }

    function onInstall(bytes calldata data) public virtual override {
        assertEq(_data, data);
        assertEq(msg.sender, address(account));
    }

    function onUninstall(bytes calldata data) public override {
        assertEq(_data, data);
        assertEq(msg.sender, address(account));
    }

    function test_WhenInstallingExecutors() external asEntryPoint {
        _data = hex"4141414141414141";
        assertFalse(account.isModuleInstalled(2, SELF, ""));
        account.installModule(2, SELF, _data);
        assertTrue(account.isModuleInstalled(2, SELF, ""));
        account.uninstallModule(2, SELF, abi.encode(address(1), _data));
        assertFalse(account.isModuleInstalled(2, SELF, ""));
    }

    function test_WhenInstallingValidators() external asEntryPoint {
        // It should call onInstall on module
        _data = hex"4141414141414141";
        assertFalse(account.isModuleInstalled(1, SELF, ""));
        account.installModule(1, SELF, _data);
        assertTrue(account.isModuleInstalled(1, SELF, ""));
        account.uninstallModule(1, SELF, abi.encode(address(1), _data));
        assertFalse(account.isModuleInstalled(1, SELF, ""));
    }

    function test_WhenInstallingFallbackModules() external asEntryPoint {
        bytes4 selector = MockTarget.set.selector;
        _data = hex"4141414141414141";

        assertFalse(account.isModuleInstalled(3, SELF, abi.encode(selector)));
        account.installModule(3, SELF, abi.encode(selector, CALLTYPE_SINGLE, _data));
        assertTrue(account.isModuleInstalled(3, SELF, abi.encode(selector)));
        account.uninstallModule(3, SELF, abi.encode(selector, _data));
        assertFalse(account.isModuleInstalled(3, SELF, abi.encode(selector)));
    }

    function _installHook(HookType hookType, bytes4 selector, bytes memory initData) public {
        bytes memory data = abi.encode(hookType, selector, initData);
        account.installModule(4, SELF, data);
        assertTrue(account.isModuleInstalled(4, SELF, abi.encode(hookType, selector)));
    }

    function _uninstallHook(HookType hookType, bytes4 selector, bytes memory initData) public {
        bytes memory data = abi.encode(hookType, selector, initData);
        account.uninstallModule(4, SELF, data);
        assertFalse(account.isModuleInstalled(4, SELF, abi.encode(hookType, selector)));
    }

    function test_WhenInstallingHooks_SIG() external asEntryPoint {
        HookType hookType = HookType.SIG;
        bytes4 selector = MockTarget.set.selector;
        _data = hex"4141414141414141";

        _installHook(hookType, selector, _data);
        _uninstallHook(hookType, selector, _data);
    }

    function test_WhenInstallingHooks_GLOBAL() external asEntryPoint {
        HookType hookType = HookType.GLOBAL;
        bytes4 selector = 0x00000000;
        _data = hex"4141414141414141";

        bytes memory data = abi.encode(hookType, selector, _data);
        account.installModule(4, SELF, data);

        account.uninstallModule(4, SELF, data);
    }

    function test_multiTypeInstall() public asEntryPoint {
        uint256[] memory types = Solarray.uint256s(1, 2);
        bytes[] memory contexts = Solarray.bytess(hex"41", hex"41");
        _data = hex"4141414141414141";
        bytes memory moduleInitData = _data;

        bytes memory initData = abi.encode(types, contexts, moduleInitData);
        account.installModule(0, SELF, initData);

        assertTrue(account.isModuleInstalled(1, SELF, ""));
        assertTrue(account.isModuleInstalled(2, SELF, ""));
    }
}
