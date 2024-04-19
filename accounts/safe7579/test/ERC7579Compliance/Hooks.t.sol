// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ModuleManagement.t.sol";
// import "src/lib/ModeLib.sol";
import "forge-std/console2.sol";

interface MockFn {
    function fallbackFn(bytes32 value) external returns (bytes32);
}

contract HookTest is ModuleManagementTest, MockFn {
    function fallbackFn(bytes32 value) external returns (bytes32) {
        return value;
    }

    function onInstall(bytes calldata data) public virtual override { }

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        override
        returns (bytes memory hookData)
    {
        console2.log("preCheck");
    }

    function setUp() public virtual override {
        super.setUp();
    }

    function test_WhenExecutingVia4337() external {
        // It should execute hook
    }

    function test_WhenExecutingViaModule() external {
        // It should execute hook
    }

    function test_WhenUsingFallbacks() external asEntryPoint {
        // It should execute hook
        _data = hex"4141414141414141";
        account.installModule(3, SELF, abi.encode(this.fallbackFn.selector, CALLTYPE_SINGLE, _data));
        _installHook(ModuleManager.HookType.SIG, this.fallbackFn.selector, "");

        bytes32 val = bytes32(bytes(hex"414141414141"));
        bytes32 ret = MockFn(address(account)).fallbackFn(val);
        assertEq(ret, val);
    }

    function test_WhenInstallingModule() external {
        // It should execute hook
    }

    function test_WhenHookReverts() external {
        // It should revert execution
    }
}
