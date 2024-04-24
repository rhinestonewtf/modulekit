// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import { ColdStorageHook, Execution } from "src/ColdStorageHook/ColdStorageHook.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { IERC3156FlashLender } from "modulekit/src/interfaces/Flashloan.sol";

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
        bytes32 executeAfter = hook.checkHash(
            address(this), keccak256(abi.encodePacked(exec.target, exec.value, exec.callData))
        );
        assertEq(executeAfter, bytes32(0));
    }

    function test_CheckHashWhenTheHashIsValid() public {
        // it should return the entry
        test_RequestTimelockedExecutionWhenTheCallIsToSetWaitPeriod();

        Execution memory exec = Execution({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10)
        });

        bytes32 executeAfter = hook.checkHash(
            address(this), keccak256(abi.encodePacked(exec.target, exec.value, exec.callData))
        );
        assertNotEq(executeAfter, bytes32(0));
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
        // it should emit an TimelockRequested event
        test_OnInstallWhenTheWaitPeriodIsNot0();

        Execution memory exec = Execution({
            target: address(hook),
            value: 0,
            callData: abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10)
        });
        uint256 additionalWait = 0;

        uint256 executeAfter = uint256(block.timestamp + _waitPeriod + additionalWait);

        bytes32 executionHash = keccak256(abi.encodePacked(exec.target, exec.value, exec.callData));

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.TimelockRequested(address(this), executionHash, executeAfter);

        hook.requestTimelockedExecution(exec, additionalWait);

        bytes32 _executeAfter = hook.checkHash(address(this), executionHash);
        assertEq(_executeAfter, bytes32(executeAfter));
    }

    function test_RequestTimelockedExecutionWhenTheReceiverIsTheOwner()
        public
        whenCalldataLengthIsNot0
    {
        // it should store the execution
        // it should store the executeAfter time
        // it should emit an TimelockRequested event
        test_OnInstallWhenTheWaitPeriodIsNot0();

        Execution memory exec = Execution({
            target: address(2),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, _owner, 10)
        });
        uint256 additionalWait = 0;

        uint256 executeAfter = uint256(block.timestamp + _waitPeriod + additionalWait);
        bytes32 executionHash = keccak256(abi.encodePacked(exec.target, exec.value, exec.callData));

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.TimelockRequested(address(this), executionHash, executeAfter);

        hook.requestTimelockedExecution(exec, additionalWait);

        bytes32 _executeAfter = hook.checkHash(address(this), executionHash);
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
        // it should emit an TimelockRequested event
        test_OnInstallWhenTheWaitPeriodIsNot0();

        Execution memory exec = Execution({ target: _owner, value: 0, callData: "" });
        uint256 additionalWait = 0;

        uint256 executeAfter = uint256(block.timestamp + _waitPeriod + additionalWait);
        bytes32 executionHash = keccak256(abi.encodePacked(exec.target, exec.value, exec.callData));

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.TimelockRequested(address(this), executionHash, executeAfter);

        hook.requestTimelockedExecution(exec, additionalWait);

        bytes32 _executeAfter = hook.checkHash(address(this), executionHash);
        assertEq(_executeAfter, bytes32(executeAfter));
    }

    function test_RequestTimelockedModuleConfigShouldStoreTheExecution() public {
        // it should store the execution
        test_OnInstallWhenTheWaitPeriodIsNot0();

        uint256 moduleTypeId = 1;
        address module = address(1);
        bytes memory initData = "";
        bool isInstall = true;
        uint256 additionalWait = 0;

        bytes4 selector;
        if (isInstall == true) {
            selector = IERC7579Account.installModule.selector;
        } else {
            selector = IERC7579Account.installModule.selector;
        }

        uint256 executeAfter = uint256(block.timestamp + _waitPeriod + additionalWait);
        bytes32 executionHash =
            keccak256(abi.encodePacked(selector, moduleTypeId, module, initData));

        hook.requestTimelockedModuleConfig(
            moduleTypeId, module, initData, isInstall, additionalWait
        );

        bytes32 _executeAfter = hook.checkHash(address(this), executionHash);
        assertEq(_executeAfter, bytes32(executeAfter));
    }

    function test_RequestTimelockedModuleConfigShouldStoreTheExecuteAfterTime() public {
        // it should store the executeAfter time
        test_OnInstallWhenTheWaitPeriodIsNot0();

        uint256 moduleTypeId = 1;
        address module = address(1);
        bytes memory initData = "";
        bool isInstall = true;
        uint256 additionalWait = 0;

        bytes4 selector;
        if (isInstall == true) {
            selector = IERC7579Account.installModule.selector;
        } else {
            selector = IERC7579Account.installModule.selector;
        }

        uint256 executeAfter = uint256(block.timestamp + _waitPeriod + additionalWait);
        bytes32 executionHash =
            keccak256(abi.encodePacked(selector, moduleTypeId, module, initData));

        hook.requestTimelockedModuleConfig(
            moduleTypeId, module, initData, isInstall, additionalWait
        );

        bytes32 _executeAfter = hook.checkHash(address(this), executionHash);
        assertEq(_executeAfter, bytes32(executeAfter));
    }

    function test_RequestTimelockedModuleConfigShouldEmitAnTimelockRequestedEvent() public {
        // it should emit an TimelockRequested event
        test_OnInstallWhenTheWaitPeriodIsNot0();

        uint256 moduleTypeId = 1;
        address module = address(1);
        bytes memory initData = "";
        bool isInstall = true;
        uint256 additionalWait = 0;

        bytes4 selector = isInstall
            ? IERC7579Account.installModule.selector
            : IERC7579Account.uninstallModule.selector;

        uint256 executeAfter = uint256(block.timestamp + _waitPeriod + additionalWait);
        bytes32 executionHash =
            keccak256(abi.encodePacked(selector, moduleTypeId, module, initData));

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.TimelockRequested(address(this), executionHash, executeAfter);

        hook.requestTimelockedModuleConfig(
            moduleTypeId, module, initData, isInstall, additionalWait
        );
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

    function test_PreCheckRevertWhen_InstallTimelockIsNotUp() public whenFunctionIsInstallModule {
        // it should revert
        uint256 moduleTypeId = 1;
        address module = address(1);
        bytes memory initData = "";
        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.installModule.selector, moduleTypeId, module, initData
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ColdStorageHook.InvalidExecutionHash.selector,
                keccak256(
                    abi.encodePacked(
                        IERC7579Account.installModule.selector, moduleTypeId, module, initData
                    )
                )
            )
        );
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckWhenInstallTimelockIsUp() public whenFunctionIsInstallModule {
        // it should emit TimelockExecuted
        // it should return
        test_RequestTimelockedModuleConfigShouldEmitAnTimelockRequestedEvent();

        uint256 moduleTypeId = 1;
        address module = address(1);
        bytes memory initData = "";
        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.installModule.selector, moduleTypeId, module, initData
        );

        bytes32 executionHash = keccak256(
            abi.encodePacked(IERC7579Account.installModule.selector, moduleTypeId, module, initData)
        );

        vm.warp(block.timestamp + _waitPeriod + 1);

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.TimelockExecuted(address(this), executionHash);

        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckRevertWhen_UninstallTimelockIsNotUp()
        public
        whenFunctionIsUninstallModule
    {
        // it should revert
        uint256 moduleTypeId = 1;
        address module = address(1);
        bytes memory initData = "";
        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.uninstallModule.selector, moduleTypeId, module, initData
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ColdStorageHook.InvalidExecutionHash.selector,
                keccak256(
                    abi.encodePacked(
                        IERC7579Account.uninstallModule.selector, moduleTypeId, module, initData
                    )
                )
            )
        );
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckWhenUninstallTimelockIsUp() public whenFunctionIsUninstallModule {
        // it should emit TimelockExecuted
        // it should return
        test_OnInstallWhenTheWaitPeriodIsNot0();

        uint256 moduleTypeId = 1;
        address module = address(1);
        bytes memory initData = "";
        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.uninstallModule.selector, moduleTypeId, module, initData
        );

        hook.requestTimelockedModuleConfig(moduleTypeId, module, initData, false, 0);

        bytes32 executionHash = keccak256(
            abi.encodePacked(
                IERC7579Account.uninstallModule.selector, moduleTypeId, module, initData
            )
        );

        vm.warp(block.timestamp + _waitPeriod + 1);

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.TimelockExecuted(address(this), executionHash);

        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckWhenFunctionIsAFlashloanFunction() external whenFunctionIsUnknown {
        // it should return
        test_RequestTimelockedExecutionWhenTheCallIsToSetWaitPeriod();

        bytes memory msgData =
            abi.encodeWithSelector(IERC3156FlashLender.maxFlashLoan.selector, makeAddr("token"));

        hook.preCheck(address(_owner), 0, msgData);
    }

    function test_PreCheckRevertWhen_FunctionIsNotAFlashloanFunction()
        external
        whenFunctionIsUnknown
    {
        // it should revert
        bytes memory msgData = abi.encodeWithSelector(IERC7579Account.supportsModule.selector, 1);

        vm.expectRevert(ColdStorageHook.UnsupportedExecution.selector);
        hook.preCheck(address(1), 0, msgData);
    }

    function test_PreCheckWhenTargetIsThisAndFunctionIsRequestTimelockedExecution()
        public
        whenFunctionIsExecuteFromExecutor
    {
        // it should return
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

        hook.preCheck(address(1), 0, msgData);
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
        // it should emit TimelockExecuted
        // it should return
        test_RequestTimelockedExecutionWhenTheCallIsToSetWaitPeriod();

        address target = address(hook);
        uint256 value = 0;
        bytes memory callData = abi.encodeWithSelector(ColdStorageHook.setWaitPeriod.selector, 10);

        bytes memory msgData = abi.encodeWithSelector(
            IERC7579Account.executeFromExecutor.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(target, value, callData)
        );

        bytes32 executionHash = keccak256(abi.encodePacked(target, value, callData));

        vm.warp(block.timestamp + _waitPeriod + 1);

        vm.expectEmit(true, true, true, true, address(hook));
        emit ColdStorageHook.TimelockExecuted(address(this), executionHash);

        hook.preCheck(address(1), 0, msgData);
    }

    function test_PostCheckShouldReturn() public {
        // it should return
        hook.postCheck("", true, "");
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

    modifier whenFunctionIsUnknown() {
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

    modifier whenFunctionIsUninstallModule() {
        _;
    }

    modifier whenFunctionIsInstallModule() {
        _;
    }
}