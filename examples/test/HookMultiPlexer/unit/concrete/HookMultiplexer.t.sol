// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest, console2 } from "test/Base.t.sol";
import {
    HookMultiPlexer,
    SigHookInit,
    HookMultiPlexerLib,
    HookType,
    HookAndContext
} from "src/HookMultiPlexer/HookMultiPlexer.sol";
import { IERC7579Account, IERC7579Module, IERC7579Hook } from "modulekit/src/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import {
    ModeLib,
    CALLTYPE_DELEGATECALL,
    EXECTYPE_DEFAULT,
    MODE_DEFAULT,
    ModePayload
} from "erc7579/lib/ModeLib.sol";
import { ExecutionLib, Execution } from "erc7579/lib/ExecutionLib.sol";
import { MockRegistry } from "test/mocks/MockRegistry.sol";
import { MockHook } from "test/mocks/MockHook.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Solarray } from "solarray/Solarray.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { MockModule } from "test/mocks/MockModule.sol";

contract HookMultiPlexerTest is BaseTest {
    using LibSort for address[];

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    HookMultiPlexer internal hook;
    MockRegistry internal _registry;
    MockHook internal subHook1;
    MockHook internal subHook2;
    MockHook internal subHook3;
    MockHook internal subHook4;
    MockHook internal subHook5;
    MockHook internal subHook6;
    MockHook internal subHook7;
    MockHook internal subHook8;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address mockModuleCode;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();
        _registry = new MockRegistry();
        hook = new HookMultiPlexer(_registry);

        mockModuleCode = address(new MockModule());

        subHook1 = new MockHook();
        subHook2 = new MockHook();
        subHook3 = new MockHook();
        subHook4 = new MockHook();
        subHook5 = new MockHook();
        subHook6 = new MockHook();
        subHook7 = new MockHook();
        subHook8 = new MockHook();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getHooks(bool sort) internal view returns (address[] memory allHooks) {
        allHooks = Solarray.addresses(
            address(subHook1),
            address(subHook2),
            address(subHook3),
            address(subHook4),
            address(subHook5),
            address(subHook7),
            address(subHook6)
        );
        if (sort) {
            allHooks.sort();
        }
    }

    function _getInitData(bool sort) internal view returns (bytes memory) {
        address[] memory allHooks = _getHooks(sort);

        address[] memory globalHooks = new address[](1);
        globalHooks[0] = address(allHooks[0]);
        address[] memory valueHooks = new address[](1);
        valueHooks[0] = address(allHooks[1]);
        address[] memory delegatecallHooks = new address[](1);
        delegatecallHooks[0] = address(allHooks[2]);

        address[] memory _sigHooks = new address[](2);
        _sigHooks[0] = address(allHooks[3]);
        _sigHooks[1] = address(allHooks[4]);

        SigHookInit[] memory sigHooks = new SigHookInit[](1);
        sigHooks[0] =
            SigHookInit({ sig: IERC7579Account.installModule.selector, subHooks: _sigHooks });

        address[] memory _targetSigHooks = new address[](2);
        _targetSigHooks[0] = address(allHooks[5]);
        _targetSigHooks[1] = address(allHooks[6]);

        SigHookInit[] memory targetSigHooks = new SigHookInit[](1);
        targetSigHooks[0] =
            SigHookInit({ sig: IERC20.transfer.selector, subHooks: _targetSigHooks });

        return abi.encode(globalHooks, valueHooks, delegatecallHooks, sigHooks, targetSigHooks);
    }

    function getPreCheckHookCallData(
        address msgSender,
        uint256 msgValue,
        bytes memory msgData
    )
        internal
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            abi.encodeCall(IERC7579Hook.preCheck, (msgSender, msgValue, msgData)),
            address(hook),
            address(this)
        );
    }

    function getPostCheckHookCallData(bytes memory preCheckContext)
        internal
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(
            abi.encodeCall(IERC7579Hook.postCheck, (preCheckContext)), address(hook), address(this)
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        bytes memory data = _getInitData(true);

        hook.onInstall(data);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.AlreadyInitialized.selector, address(this))
        );
        hook.onInstall(data);
    }

    function test_OnInstallRevertWhen_AnyOfTheHooksAreNotSortedAndUnique()
        public
        whenModuleIsNotIntialized
    {
        // it should revert
        bytes memory data = _getInitData(false);

        vm.expectRevert();
        hook.onInstall(data);
    }

    function test_OnInstallWhenAllOfTheHooksAreSortedAndUnique() public whenModuleIsNotIntialized {
        // it should set all the hooks
        bytes memory data = _getInitData(true);

        hook.onInstall(data);

        address[] memory hooks = hook.getHooks(address(this));
        assertEq(hooks.length, 7);
    }

    function test_OnUninstallShouldDeleteAllTheHooksAndSigs() public {
        // it should delete all the hooks and sigs
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        hook.onUninstall("");

        address[] memory hooks = hook.getHooks(address(this));
        assertEq(hooks.length, 0);
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool isInitialized = hook.isInitialized(address(this));
        assertFalse(isInitialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        bool isInitialized = hook.isInitialized(address(this));
        assertTrue(isInitialized);
    }

    function test_GetHooksShouldReturnAllTheHooks() public {
        // it should return all the hooks
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        address[] memory hooks = hook.getHooks(address(this));
        assertEq(hooks.length, 7);
    }

    function test_AddHookRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        hook.addHook(address(subHook8), HookType.GLOBAL);
    }

    function test_AddHookWhenModuleIsIntialized() public {
        // it should add the hook
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        hook.addHook(address(subHook8), HookType.GLOBAL);

        address[] memory hooks = hook.getHooks(address(this));
        assertEq(hooks.length, 8);
    }

    function test_AddSigHookRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        hook.addSigHook(address(subHook8), IERC7579Account.installModule.selector, HookType.SIG);
    }

    function test_AddSigHookWhenModuleIsIntialized() public whenModuleIsIntialized {
        // it should add the hook
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        hook.addSigHook(address(subHook8), IERC7579Account.installModule.selector, HookType.SIG);

        address[] memory hooks = hook.getHooks(address(this));
        assertEq(hooks.length, 8);
    }

    function test_AddSigHookWhenSigIsNotAlreadyAdded() public whenModuleIsIntialized {
        // it should add the sig
        test_AddSigHookWhenModuleIsIntialized();
    }

    function test_RemoveHookShouldRemoveTheHook() public {
        // it should remove the hook
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        address[] memory __hooks = hook.getHooks(address(this));
        assertEq(__hooks.length, 7);

        address[] memory _hooks = _getHooks(true);

        hook.removeHook(address(_hooks[0]), HookType.GLOBAL);

        address[] memory hooks = hook.getHooks(address(this));
        assertEq(hooks.length, 6);
    }

    function test_RemoveSigHookShouldRemoveTheHook() public {
        // it should remove the hook
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        address[] memory _hooks = _getHooks(true);

        hook.removeSigHook(address(_hooks[3]), IERC7579Account.installModule.selector, HookType.SIG);

        address[] memory hooks = hook.getHooks(address(this));
        assertEq(hooks.length, 6);
    }

    function test_RemoveSigHookWhenSigWasOnlyUsedByThisHook() public {
        // it should remove the sig
        test_RemoveSigHookShouldRemoveTheHook();
    }

    function test_PreCheckWhenTxIsNotAnExecution() public {
        // it should call global and calldata hooks
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        address newModule = makeAddr("newModule");
        vm.etch(newModule, mockModuleCode.code);

        address msgSender = address(1);
        uint256 msgValue = 0;
        bytes memory msgData =
            abi.encodeWithSelector(IERC7579Account.installModule.selector, 1, newModule, "");

        address[] memory _hooks = _getHooks(true);
        vm.expectCall(_hooks[0], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);
        vm.expectCall(_hooks[3], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);
        vm.expectCall(_hooks[4], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);

        hook.preCheck(msgSender, msgValue, msgData);
    }

    function test_PreCheckWhenTxIsAnExecution() public whenTxIsAnExecution {
        // it should call global hooks
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        address msgSender = address(1);
        uint256 msgValue = 0;
        bytes memory msgData = abi.encodeCall(
            IERC7579Account.execute,
            (ModeLib.encodeSimpleSingle(), ExecutionLib.encodeSingle(address(1), 0, ""))
        );

        address[] memory _hooks = _getHooks(true);
        vm.expectCall(_hooks[0], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);

        hook.preCheck(msgSender, msgValue, msgData);
    }

    function test_PreCheckWhenExecutionHasValue()
        public
        whenTxIsAnExecution
        whenExecutionIsSingle
    {
        // it should call the target sig hooks
        // it should call the value hooks
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        address msgSender = address(1);
        uint256 msgValue = 0;
        bytes memory msgData = abi.encodeCall(
            IERC7579Account.execute,
            (
                ModeLib.encodeSimpleSingle(),
                ExecutionLib.encodeSingle(
                    address(1), 1, abi.encodeCall(IERC20.transfer, (address(1), 1))
                )
            )
        );

        address[] memory _hooks = _getHooks(true);
        vm.expectCall(_hooks[0], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);
        vm.expectCall(_hooks[5], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);
        vm.expectCall(_hooks[6], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);

        hook.preCheck(msgSender, msgValue, msgData);
    }

    function test_PreCheckWhenExecutionHasNoValue()
        public
        whenTxIsAnExecution
        whenExecutionIsSingle
    {
        // it should call the target sig hooks
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        address msgSender = address(1);
        uint256 msgValue = 0;
        bytes memory msgData = abi.encodeCall(
            IERC7579Account.execute,
            (
                ModeLib.encodeSimpleSingle(),
                ExecutionLib.encodeSingle(
                    address(1), 0, abi.encodeCall(IERC20.transfer, (address(1), 1))
                )
            )
        );

        address[] memory _hooks = _getHooks(true);
        vm.expectCall(_hooks[5], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);
        vm.expectCall(_hooks[6], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);

        hook.preCheck(msgSender, msgValue, msgData);
    }

    function test_PreCheckWhenAnyExecutionHasValue()
        public
        whenTxIsAnExecution
        whenExecutionIsBatched
    {
        // it should call the target sig hooks
        // it should call the value hooks
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(1), value: 1, callData: "" });
        executions[1] = Execution({
            target: address(1),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (address(1), 1))
        });

        address msgSender = address(1);
        uint256 msgValue = 0;
        bytes memory msgData = abi.encodeCall(
            IERC7579Account.execute,
            (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions))
        );

        address[] memory _hooks = _getHooks(true);
        vm.expectCall(_hooks[0], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);
        vm.expectCall(_hooks[5], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);
        vm.expectCall(_hooks[6], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);

        hook.preCheck(msgSender, msgValue, msgData);
    }

    function test_PreCheckWhenNoExecutionHasValue()
        public
        whenTxIsAnExecution
        whenExecutionIsBatched
    {
        // it should call the target sig hooks
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(1),
            value: 0,
            callData: abi.encodeCall(IERC20.transferFrom, (address(1), address(1), 1))
        });
        executions[1] = Execution({
            target: address(1),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (address(1), 1))
        });

        address msgSender = address(1);
        uint256 msgValue = 0;
        bytes memory msgData = abi.encodeCall(
            IERC7579Account.execute,
            (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions))
        );

        address[] memory _hooks = _getHooks(true);
        vm.expectCall(_hooks[5], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);
        vm.expectCall(_hooks[6], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);

        hook.preCheck(msgSender, msgValue, msgData);
    }

    function test_PreCheckWhenExecutionIsDelegatecall() public whenTxIsAnExecution {
        // it should call the delegatecall hooks
        test_OnInstallWhenAllOfTheHooksAreSortedAndUnique();

        address msgSender = address(1);
        uint256 msgValue = 0;
        bytes memory msgData = abi.encodeCall(
            IERC7579Account.execute,
            (
                ModeLib.encode(
                    CALLTYPE_DELEGATECALL, EXECTYPE_DEFAULT, MODE_DEFAULT, ModePayload.wrap(0x00)
                ),
                ExecutionLib.encodeSingle(
                    address(1), 0, abi.encodeCall(IERC20.transfer, (address(1), 1))
                )
            )
        );

        address[] memory _hooks = _getHooks(true);
        vm.expectCall(_hooks[2], 0, getPreCheckHookCallData(msgSender, msgValue, msgData), 1);

        hook.preCheck(msgSender, msgValue, msgData);
    }

    function test_PostCheckShouldCallAllHooksProvidedInHookdata() public {
        // it should call all hooks provided in hookdata
        address[] memory _hooks = _getHooks(true);
        HookAndContext[] memory hookAndContexts = new HookAndContext[](_hooks.length);

        for (uint256 i; i < _hooks.length; i++) {
            bytes memory context = abi.encode("pass");
            hookAndContexts[i] = HookAndContext({ hook: _hooks[i], context: context });
            // vm.expectCall(_hooks[i], 0, getPostCheckHookCallData(context), 1);
            // todo: is this a bug?
            vm.expectCall(_hooks[i], 0, bytes(abi.encode(bytes4(0x173bf7da))), 1);
        }

        bytes memory hookData = abi.encode(hookAndContexts);

        hook.postCheck(hookData);
    }

    function test_NameShouldReturnHookMultiPlexer() public {
        // it should return HookMultiPlexer
        string memory name = hook.name();
        assertEq(name, "HookMultiPlexer");
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

    modifier whenModuleIsNotIntialized() {
        _;
    }

    modifier whenModuleIsIntialized() {
        _;
    }

    modifier whenTxIsAnExecution() {
        _;
    }

    modifier whenExecutionIsSingle() {
        _;
    }

    modifier whenExecutionIsBatched() {
        _;
    }
}
