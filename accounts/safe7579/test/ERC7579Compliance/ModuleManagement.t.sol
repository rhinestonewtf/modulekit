// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.t.sol";
import "erc7579/lib/ModeLib.sol";
import { EventEmitter } from "src/utils/DelegatecallTarget.sol";

contract ModuleManagementTest is BaseTest {
    bytes _data;

    function setUp() public virtual override {
        super.setUp();
    }

    function onInstall(bytes calldata data) public override {
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

    function test_WhenInstallingHooks() external asEntryPoint {
        bytes4 selector = MockTarget.set.selector;
        _data = hex"4141414141414141";

        assertFalse(account.isModuleInstalled(4, SELF, abi.encode(selector)));
        account.installModule(4, SELF, abi.encode(selector, _data));
        assertTrue(account.isModuleInstalled(4, SELF, abi.encode(selector)));
        account.uninstallModule(4, SELF, abi.encode(selector, _data));
        assertFalse(account.isModuleInstalled(4, SELF, abi.encode(selector)));
    }
}
