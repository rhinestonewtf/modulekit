// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import { ColdStorageHook, Execution } from "src/ColdStorageHook/ColdStorageHook.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";

contract ColdStorageHookTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ColdStorageHook internal hook;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address _owner;
    uint128 _waitPeriod;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();
        hook = new ColdStorageHook();

        _owner = makeAddr("owner");
        _waitPeriod = uint128(100);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        bytes memory data = abi.encodePacked(_waitPeriod, _owner);

        hook.onInstall(data);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.AlreadyInitialized.selector, address(this))
        );
        hook.onInstall(data);
    }

    function test_OnInstallRevertWhen_TheOwnerIs0() public whenModuleIsNotIntialized {
        // it should revert
        bytes memory data = abi.encodePacked(_waitPeriod, address(0));

        vm.expectRevert(ColdStorageHook.InvalidOwner.selector);
        hook.onInstall(data);
    }

    function test_OnInstallRevertWhen_TheWaitPeriodIs0()
        public
        whenModuleIsNotIntialized
        whenTheOwnerIsNot0
    {
        // it should revert
        bytes memory data = abi.encodePacked(uint128(0), _owner);

        vm.expectRevert(ColdStorageHook.InvalidWaitPeriod.selector);
        hook.onInstall(data);
    }

    function test_OnInstallWhenTheWaitPeriodIsNot0()
        public
        whenModuleIsNotIntialized
        whenTheOwnerIsNot0
    {
        // it should set the waitPeriod
        // it should set the owner
        bytes memory data = abi.encodePacked(_waitPeriod, _owner);

        hook.onInstall(data);

        (uint128 waitPeriod, address owner) = hook.vaultConfig(address(this));
        assertEq(waitPeriod, _waitPeriod);
        assertEq(owner, _owner);
    }

    function test_OnUninstallShouldRemoveTheConfig() public {
        // it should remove the config
        test_OnInstallWhenTheWaitPeriodIsNot0();

        hook.onUninstall("");

        (uint128 waitPeriod, address owner) = hook.vaultConfig(address(this));
        assertEq(waitPeriod, uint128(0));
        assertEq(owner, address(0));
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool isInitialized = hook.isInitialized(address(this));
        assertFalse(isInitialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenTheWaitPeriodIsNot0();

        bool isInitialized = hook.isInitialized(address(this));
        assertTrue(isInitialized);
    }

    function test_SetWaitPeriodRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        hook.setWaitPeriod(10);
    }

    function test_SetWaitPeriodRevertWhen_WaitPeriodIs0() public whenModuleIsIntialized {
        // it should revert
        test_OnInstallWhenTheWaitPeriodIsNot0();

        vm.expectRevert(ColdStorageHook.InvalidWaitPeriod.selector);
        hook.setWaitPeriod(0);
    }

    function test_SetWaitPeriodWhenWaitPeriodIsNot0() public whenModuleIsIntialized {
        // it should set the waitPeriod
        test_OnInstallWhenTheWaitPeriodIsNot0();
        uint256 newWaitPeriod = 10;
        assertNotEq(_waitPeriod, uint128(newWaitPeriod));

        hook.setWaitPeriod(newWaitPeriod);

        (uint128 waitPeriod,) = hook.vaultConfig(address(this));
        assertEq(waitPeriod, uint128(newWaitPeriod));
    }

    function test_CheckHashWhenTheHashIsNotValid() public {
        // it should return entry 0
        test_OnInstallWhenTheWaitPeriodIsNot0();

        Execution memory exec = Execution({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10)
        });

        (bytes32 executionHash, bytes32 entry) = hook.checkHash(address(this), exec);
        assertEq(entry, bytes32(0));
        assertEq(executionHash, keccak256(abi.encodePacked(exec.target, exec.value, exec.callData)));
    }

    function test_CheckHashWhenTheHashIsValid() public {
        // it should return the execution hash
        // it should return the entry
        test_RequestTimelockedExecutionWhenTheCallIsToSetWaitPeriod();

        Execution memory exec = Execution({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10)
        });

        (bytes32 executionHash, bytes32 entry) = hook.checkHash(address(this), exec);
        assertNotEq(entry, bytes32(0));
        assertEq(executionHash, keccak256(abi.encodePacked(exec.target, exec.value, exec.callData)));
    }

    function test_RequestTimelockedExecutionRevertWhen_TheCallIsNotToSetWaitPeriod()
        public
        whenCalldataLengthIsNot0
        whenTheReceiverIsNotTheOwner
    {
        // it should revert
        test_OnInstallWhenTheWaitPeriodIsNot0();

        Execution memory exec = Execution({
            target: address(2),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, address(3), 10)
        });

        vm.expectRevert(ColdStorageHook.InvalidTransferReceiver.selector);
        hook.requestTimelockedExecution(exec, 0);
    }

    function test_RequestTimelockedExecutionWhenTheCallIsToSetWaitPeriod()
        public
        whenCalldataLengthIsNot0
        whenTheReceiverIsNotTheOwner
    {
        // it should store the execution
        // it should store the executeAfter time
        // it should emit an ExecutionRequested event
        test_OnInstallWhenTheWaitPeriodIsNot0();

        Execution memory exec = Execution({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10)
        });
        uint256 additionalWait = 0;

        uint256 executeAfter = uint256(block.timestamp + _waitPeriod + additionalWait);

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.ExecutionRequested(
            address(this), exec.target, exec.value, exec.callData, executeAfter
        );

        hook.requestTimelockedExecution(exec, additionalWait);

        bytes32 executionHash = keccak256(abi.encodePacked(exec.target, exec.value, exec.callData));
        bytes32 _executeAfter = hook.getExecution(address(this), executionHash);
        assertEq(_executeAfter, bytes32(executeAfter));
    }

    function test_RequestTimelockedExecutionWhenTheReceiverIsTheOwner()
        public
        whenCalldataLengthIsNot0
    {
        // it should store the execution
        // it should store the executeAfter time
        // it should emit an ExecutionRequested event
        test_OnInstallWhenTheWaitPeriodIsNot0();

        Execution memory exec = Execution({
            target: address(2),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, _owner, 10)
        });
        uint256 additionalWait = 0;

        uint256 executeAfter = uint256(block.timestamp + _waitPeriod + additionalWait);

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.ExecutionRequested(
            address(this), exec.target, exec.value, exec.callData, executeAfter
        );

        hook.requestTimelockedExecution(exec, additionalWait);

        bytes32 executionHash = keccak256(abi.encodePacked(exec.target, exec.value, exec.callData));
        bytes32 _executeAfter = hook.getExecution(address(this), executionHash);
        assertEq(_executeAfter, bytes32(executeAfter));
    }

    function test_RequestTimelockedExecutionRevertWhen_TheTargetIsNotTheOwner()
        public
        whenCalldataLengthIs0
    {
        // it should revert
        test_OnInstallWhenTheWaitPeriodIsNot0();

        Execution memory exec = Execution({ target: address(2), value: 0, callData: "" });
        uint256 additionalWait = 0;

        vm.expectRevert(ColdStorageHook.InvalidTransferReceiver.selector);
        hook.requestTimelockedExecution(exec, additionalWait);
    }

    function test_RequestTimelockedExecutionWhenTheTargetIsTheOwner()
        public
        whenCalldataLengthIs0
    {
        // it should store the execution
        // it should store the executeAfter time
        // it should emit an ExecutionRequested event
        test_OnInstallWhenTheWaitPeriodIsNot0();

        Execution memory exec = Execution({ target: _owner, value: 0, callData: "" });
        uint256 additionalWait = 0;

        uint256 executeAfter = uint256(block.timestamp + _waitPeriod + additionalWait);

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.ExecutionRequested(
            address(this), exec.target, exec.value, exec.callData, executeAfter
        );

        hook.requestTimelockedExecution(exec, additionalWait);

        bytes32 executionHash = keccak256(abi.encodePacked(exec.target, exec.value, exec.callData));
        bytes32 _executeAfter = hook.getExecution(address(this), executionHash);
        assertEq(_executeAfter, bytes32(executeAfter));
    }

    function test_PreCheckRevertWhen_FunctionIsExecute() public {
        // it should revert
        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(1), 0, "")
        );

        vm.expectRevert(ColdStorageHook.UnsupportedExecution.selector);
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckRevertWhen_FunctionIsExecuteBatch() public {
        // it should revert
        Execution[] memory execs = new Execution[](1);
        execs[0] = Execution({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10)
        });

        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            ModeLib.encodeSimpleBatch(),
            ExecutionLib.encodeBatch(execs)
        );

        vm.expectRevert(ColdStorageHook.UnsupportedExecution.selector);
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckRevertWhen_FunctionIsExecuteBatchFromExecutor() public {
        // it should revert
        Execution[] memory execs = new Execution[](1);
        execs[0] = Execution({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10)
        });

        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.executeFromExecutor.selector,
            ModeLib.encodeSimpleBatch(),
            ExecutionLib.encodeBatch(execs)
        );

        vm.expectRevert(ColdStorageHook.UnsupportedExecution.selector);
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckRevertWhen_FunctionIsInstallModule() public {
        // it should revert
        bytes memory msgData =
            abi.encodeWithSelector(IERC7579Account.installModule.selector, 1, address(1), "");

        vm.expectRevert(ColdStorageHook.UnsupportedExecution.selector);
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckRevertWhen_FunctionIsUninstallModule() public {
        // it should revert
        bytes memory msgData =
            abi.encodeWithSelector(IERC7579Account.uninstallModule.selector, 1, address(1), "");

        vm.expectRevert(ColdStorageHook.UnsupportedExecution.selector);
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckRevertWhen_FunctionIsUnknown() public {
        // it should revert
        bytes memory msgData = abi.encodeWithSelector(IERC7579Account.supportsModule.selector, 1);

        vm.expectRevert(ColdStorageHook.UnsupportedExecution.selector);
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckWhenTargetIsThisAndFunctionIsRequestTimelockedExecution()
        public
        whenFunctionIsExecuteFromExecutor
    {
        // it should return requestTimelockedExecution
        Execution memory exec = Execution({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10)
        });
        uint256 additionalWait = 0;

        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.executeFromExecutor.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(
                address(hook),
                0,
                abi.encodeWithSelector(
                    ColdStorageHook.requestTimelockedExecution.selector, exec, additionalWait
                )
            )
        );

        bytes memory hookData = hook.preCheck(address(1), 0, msgData);
        assertEq(hookData, abi.encode(ColdStorageHook.requestTimelockedExecution.selector));
    }

    function test_PreCheckRevertWhen_AnExecutionDoesNotExist()
        public
        whenFunctionIsExecuteFromExecutor
        whenTargetIsNotThisOrFunctionIsNotRequestTimelockedExecution
    {
        // it should revert
        address target = address(hook);
        uint256 value = 0;
        bytes memory callData = abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10);

        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.executeFromExecutor.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(target, value, callData)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ColdStorageHook.InvalidExecutionHash.selector,
                keccak256(abi.encodePacked(target, value, callData))
            )
        );
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckRevertWhen_TheTimelockIsNotUp()
        public
        whenFunctionIsExecuteFromExecutor
        whenTargetIsNotThisOrFunctionIsNotRequestTimelockedExecution
        whenAnExecutionExists
    {
        // it should revert
        test_RequestTimelockedExecutionWhenTheCallIsToSetWaitPeriod();

        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.executeFromExecutor.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(
                address(hook), 0, abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10)
            )
        );

        vm.expectRevert(ColdStorageHook.UnauthorizedAccess.selector);
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckWhenTheTimelockIsUp()
        public
        whenFunctionIsExecuteFromExecutor
        whenTargetIsNotThisOrFunctionIsNotRequestTimelockedExecution
        whenAnExecutionExists
    {
        // it should emit ExecutionExecuted
        // it should return pass
        test_RequestTimelockedExecutionWhenTheCallIsToSetWaitPeriod();

        address target = address(hook);
        uint256 value = 0;
        bytes memory callData = abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10);

        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.executeFromExecutor.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(target, value, callData)
        );

        vm.warp(block.timestamp + _waitPeriod + 1);

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.ExecutionExecuted(address(this), target, value, callData);

        bytes memory hookData = hook.preCheck(address(1), 0, msgData);
        assertEq(hookData, abi.encode(keccak256("pass")));
    }

    function test_PostCheckRevertWhen_HookDataIsNotRequestTimelockedExecutionOrPass() public {
        // it should revert
        vm.expectRevert(ColdStorageHook.UnauthorizedAccess.selector);
        hook.postCheck("0x", false, "0x");
    }

    function test_PostCheckWhenHookDataIsRequestTimelockedExecution() public {
        // it should return
        hook.postCheck(abi.encode(ColdStorageHook.requestTimelockedExecution.selector), false, "0x");
    }

    function test_PostCheckWhenHookDataIsPass() public {
        // it should return
        hook.postCheck(abi.encode(keccak256("pass")), false, "0x");
    }

    function test_NameShouldReturnColdStorageHook() public {
        // it should return ColdStorageHook
        string memory name = hook.name();
        assertEq(name, "ColdStorageHook");
    }

    function test_VersionShouldReturn100() public {
        // it should return 1.0.0
        string memory version = hook.version();
        assertEq(version, "1.0.0");
    }

    function test_IsModuleTypeWhenTypeIDIs4() public {
        // it should return true
        bool isModuleType = hook.isModuleType(4);
        assertTrue(isModuleType);
    }

    function test_IsModuleTypeWhenTypeIDIsNot4() public {
        // it should return false
        bool isModuleType = hook.isModuleType(1);
        assertFalse(isModuleType);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenTheOwnerIsNot0() {
        _;
    }

    modifier whenModuleIsNotIntialized() {
        _;
    }

    modifier whenModuleIsIntialized() {
        _;
    }

    modifier whenCalldataLengthIsNot0() {
        _;
    }

    modifier whenTheReceiverIsNotTheOwner() {
        _;
    }

    modifier whenCalldataLengthIs0() {
        _;
    }

    modifier whenFunctionIsExecuteFromExecutor() {
        _;
    }

    modifier whenTargetIsNotThisOrFunctionIsNotRequestTimelockedExecution() {
        _;
    }

    modifier whenAnExecutionExists() {
        _;
    }
}
