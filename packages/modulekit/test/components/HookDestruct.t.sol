// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "src/modules/ERC7579HookDestruct.sol";
import { IERC7579Account } from "src/external/ERC7579.sol";

import "forge-std/Test.sol";
import { ExecutionLib, Execution } from "erc7579/lib/ExecutionLib.sol";

contract HookDestructTest is Test, ERC7579HookDestruct {
    struct Log {
        address msgSender;
        uint256 msgValue;
        bytes msgData;
        mapping(uint256 index => Execution) executions;
        uint256 executionsLength;
    }

    struct InstallLog {
        address module;
        uint256 moduleType;
        bytes initData;
    }

    Log _log;
    InstallLog _installLog;

    function setUp() public { }

    function test_executeSingle(
        address msgSender,
        uint256 msgValue,
        address target,
        uint256 value,
        bytes memory data
    )
        public
    {
        vm.assume(data.length > 0);
        ModeCode mode = ModeLib.encodeSimpleSingle();
        bytes memory execution = ExecutionLib.encodeSingle(target, value, data);
        bytes memory callData =
            abi.encodeCall(IERC7579Account.executeFromExecutor, (mode, execution));
        _log.msgData = callData;
        _log.msgValue = msgValue;
        _log.msgSender = msgSender;

        _log.executionsLength = 1;
        _log.executions[0].target = target;
        _log.executions[0].value = value;
        _log.executions[0].callData = data;

        bytes memory hookData =
            ERC7579HookDestruct(address(this)).preCheck(msgSender, msgValue, callData);
        assertEq(hookData, "onExecute");
    }

    function test_executeBatch(
        address msgSender,
        uint256 msgValue,
        Execution[] memory _execution
    )
        public
    {
        vm.assume(_execution.length > 0);
        ModeCode mode = ModeLib.encodeSimpleBatch();
        bytes memory execution = ExecutionLib.encodeBatch(_execution);
        bytes memory callData =
            abi.encodeCall(IERC7579Account.executeFromExecutor, (mode, execution));

        _log.msgData = callData;
        _log.msgValue = msgValue;
        _log.msgSender = msgSender;

        _log.executionsLength = _execution.length;
        for (uint256 i; i < _execution.length; i++) {
            _log.executions[i].target = _execution[i].target;
            _log.executions[i].value = _execution[i].value;
            _log.executions[i].callData = _execution[i].callData;
        }

        bytes memory hookData =
            ERC7579HookDestruct(address(this)).preCheck(msgSender, msgValue, callData);
        assertEq(hookData, "onExecuteBatch");
    }

    function test_installModule(
        address msgSender,
        uint256 msgValue,
        address moduleAddress,
        uint256 moduleType,
        bytes memory data
    )
        public
    {
        vm.assume(data.length > 0);
        moduleType = moduleType % 5;
        bytes memory callData =
            abi.encodeCall(IERC7579Account.installModule, (moduleType, moduleAddress, data));
        _log.msgData = callData;
        _log.msgValue = msgValue;
        _log.msgSender = msgSender;

        _installLog.module = moduleAddress;
        _installLog.moduleType = moduleType;
        _installLog.initData = data;

        bytes memory hookData =
            ERC7579HookDestruct(address(this)).preCheck(msgSender, msgValue, callData);
        assertEq(hookData, "onInstall", "return value wrong");
    }

    function onExecute(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        assertTrue(_log.msgSender == msgSender);
        assertTrue(_log.executionsLength == 1);

        assertEq(_log.executions[0].callData, callData, "callData decoding failed");
        assertEq(_log.executions[0].value, value);
        assertEq(_log.executions[0].target, target);

        hookData = "onExecute";
    }

    function onExecuteBatch(
        address msgSender,
        Execution[] calldata executions
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        assertTrue(_log.msgSender == msgSender);
        assertEq(_log.executionsLength, executions.length);

        for (uint256 i; i < executions.length; i++) {
            assertEq(_log.executions[i].callData, executions[i].callData);
            assertEq(_log.executions[i].value, executions[i].value);
            assertEq(_log.executions[i].target, executions[i].target);
        }

        return "onExecuteBatch";
    }

    function onExecuteFromExecutor(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        assertTrue(_log.msgSender == msgSender);
        assertTrue(_log.executionsLength == 1);

        assertEq(_log.executions[0].callData, callData, "callData decoding failed");
        assertEq(_log.executions[0].value, value);
        assertEq(_log.executions[0].target, target);

        hookData = "onExecute";
    }

    function onExecuteBatchFromExecutor(
        address msgSender,
        Execution[] calldata executions
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        assertTrue(_log.msgSender == msgSender);
        assertEq(_log.executionsLength, executions.length);

        for (uint256 i; i < executions.length; i++) {
            assertEq(_log.executions[i].callData, executions[i].callData);
            assertEq(_log.executions[i].value, executions[i].value);
            assertEq(_log.executions[i].target, executions[i].target);
        }

        return "onExecuteBatch";
    }

    function onInstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        assertEq(_log.msgSender, msgSender);

        assertEq(_installLog.module, module);
        assertEq(_installLog.moduleType, moduleType);
        assertEq(_installLog.initData, initData);

        hookData = "onInstall";
    }

    function onUninstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onPostCheck(
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        internal
        virtual
        override
    { }

    function onInstall(bytes calldata) public { }
    function onUninstall(bytes calldata) public { }

    function isInitialized(address smartAccount) public view returns (bool) { }
    function isModuleType(uint256 moduleType) public pure returns (bool) { }
}
