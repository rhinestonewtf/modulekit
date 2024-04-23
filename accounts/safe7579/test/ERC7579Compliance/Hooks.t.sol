// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ModuleManagement.t.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import "forge-std/console2.sol";

interface MockFn {
    function fallbackFn(bytes32 value) external returns (bytes32);
}

contract HookTest is BaseTest, MockFn {
    uint256 preCheckCalled;
    uint256 postCheckCalled;
    bytes _data;
    address _caller;

    modifier requireHookCalled(uint256 expected) {
        preCheckCalled = 0;
        postCheckCalled = 0;
        _;
        assertEq(preCheckCalled, expected, "preCheckCalled");
        assertEq(postCheckCalled, expected, "postCheckCalled");
    }

    function fallbackFn(bytes32 value) external returns (bytes32) {
        return value;
    }

    function onInstall(bytes calldata data) public virtual override {
        assertEq(_data, data);
        assertEq(msg.sender, address(account));
    }

    function onUninstall(bytes calldata data) public override {
        assertEq(_data, data);
        assertEq(msg.sender, address(account));
    }

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        override
        returns (bytes memory hookData)
    {
        preCheckCalled++;
        assertEq(msgSender, address(_caller));
        console2.log("preCheck");

        return hex"beef";
    }

    function postCheck(bytes calldata hookData) external virtual override {
        postCheckCalled++;
        assertEq(hookData, hex"beef");
    }

    function setUp() public virtual override {
        super.setUp();
    }

    function test_WhenExecutingVia4337() external requireHookCalled(1) {
        _data = hex"4141414141414141";
        _caller = address(entrypoint);
        vm.startPrank(address(entrypoint));

        bytes memory data = abi.encode(HookType.GLOBAL, 0x0, _data);
        account.installModule(4, SELF, data);

        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.set, 1337);
        account.execute(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(target), uint256(0), setValueOnTarget)
        );
        vm.stopPrank();
    }

    function test_WhenExecutingViaModule() external requireHookCalled(1) {
        _data = hex"4141414141414141";
        _caller = address(this);
        vm.startPrank(address(entrypoint));
        // installing this test as an executor
        account.installModule(2, SELF, _data);

        bytes memory data = abi.encode(HookType.GLOBAL, 0x0, _data);
        account.installModule(4, SELF, data);

        vm.stopPrank();

        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.set, 1337);
        account.executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(target), uint256(0), setValueOnTarget)
        );
    }

    function test_WhenUsingFallbacks() external requireHookCalled(2) {
        // It should execute hook
        _data = hex"4141414141414141";
        _caller = address(this);
        vm.startPrank(address(entrypoint));
        // installing fallback
        account.installModule(3, SELF, abi.encode(this.fallbackFn.selector, CALLTYPE_SINGLE, _data));

        bytes memory data = abi.encode(HookType.SIG, this.fallbackFn.selector, _data);
        account.installModule(4, SELF, data);
        data = abi.encode(HookType.GLOBAL, 0x0, _data);
        account.installModule(4, SELF, data);
        vm.stopPrank();

        bytes32 val = bytes32(bytes(hex"414141414141"));
        // calling fallback
        bytes32 ret = MockFn(address(account)).fallbackFn(val);
        assertEq(ret, val);
    }

    function test_WhenInstallingModule() external requireHookCalled(3) {
        // It should execute hook
        _data = hex"4141414141414141";
        _caller = address(entrypoint);
        vm.startPrank(address(entrypoint));

        bytes memory data = abi.encode(HookType.SIG, IERC7579Account.installModule.selector, _data);
        account.installModule(4, SELF, data);
        data = abi.encode(HookType.GLOBAL, 0x0, _data);
        account.installModule(4, SELF, data);

        // installing fallback
        account.installModule(2, SELF, _data);
        vm.stopPrank();
    }

    function test_WhenHookReverts() external {
        // It should revert execution
    }
}
