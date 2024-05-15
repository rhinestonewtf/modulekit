// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp
} from "test/BaseIntegration.t.sol";
import { UserOpData } from "modulekit/src/ModuleKit.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_EXECUTOR,
    IERC7579Account,
    IERC7579Module
} from "modulekit/src/external/ERC7579.sol";

import { HookMultiPlexer, HookType } from "src/HookMultiPlexer/HookMultiPlexer.sol";
import "forge-std/interfaces/IERC20.sol";
import { MockHook } from "test/mocks/MockHook.sol";
import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";

import "erc7579/lib/ModeLib.sol";
import { MockTarget } from "modulekit/src/mocks/MockTarget.sol";
import "forge-std/interfaces/IERC20.sol";
import "src/HookMultiPlexer/DataTypes.sol";
import { Solarray } from "solarray/Solarray.sol";
import { LibSort } from "solady/utils/LibSort.sol";

import { TrustedForwarder } from "modulekit/src/modules/utils/TrustedForwarder.sol";

import { DeadmanSwitch } from "src/DeadmanSwitch/DeadmanSwitch.sol";
import { ColdStorageHook } from "src/ColdStorageHook/ColdStorageHook.sol";
import { RegistryHook, IERC7484 } from "src/RegistryHook/RegistryHook.sol";

import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { MockModule } from "test/mocks/MockModule.sol";

import "forge-std/console2.sol";

contract HookMultiPlexerIntegrationTest is BaseIntegrationTest {
    using LibSort for address[];
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    HookMultiPlexer internal hook;

    MockHook internal subHook1;
    MockHook internal subHook2;
    MockHook internal subHook3;
    MockHook internal subHook4;
    MockHook internal subHook5;
    MockHook internal subHook6;
    MockHook internal subHook7;
    MockHook internal subHook8;

    MockTarget internal target;
    MockERC20 internal token;

    ColdStorageHook internal coldStorage;
    DeadmanSwitch internal deadmanSwitch;
    RegistryHook internal registryHook;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address mockModuleCode;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        BaseIntegrationTest.setUp();

        vm.warp(100);

        target = new MockTarget();

        mockModuleCode = address(new MockModule());

        hook = new HookMultiPlexer(instance.aux.registry);
        subHook1 = new MockHook();
        subHook2 = new MockHook();
        subHook3 = new MockHook();
        subHook4 = new MockHook();
        subHook5 = new MockHook();
        subHook6 = new MockHook();
        subHook7 = new MockHook();
        subHook8 = new MockHook();

        coldStorage = new ColdStorageHook();
        deadmanSwitch = new DeadmanSwitch();
        registryHook = new RegistryHook();

        Execution[] memory execution = new Execution[](6);
        execution[0] = Execution({
            target: address(coldStorage),
            value: 0,
            callData: abi.encodeCall(
                IERC7579Module.onInstall, (abi.encodePacked(uint128(1), address(1)))
            )
        });

        execution[1] = Execution({
            target: address(deadmanSwitch),
            value: 0,
            callData: abi.encodeCall(
                IERC7579Module.onInstall, (abi.encodePacked(address(1), uint48(1)))
            )
        });

        execution[2] = Execution({
            target: address(registryHook),
            value: 0,
            callData: abi.encodeCall(
                IERC7579Module.onInstall, (abi.encodePacked(address(instance.aux.registry)))
            )
        });

        execution[3] = Execution({
            target: address(coldStorage),
            value: 0,
            callData: abi.encodeCall(TrustedForwarder.setTrustedForwarder, (address(hook)))
        });

        execution[4] = Execution({
            target: address(deadmanSwitch),
            value: 0,
            callData: abi.encodeCall(TrustedForwarder.setTrustedForwarder, (address(hook)))
        });

        execution[5] = Execution({
            target: address(registryHook),
            value: 0,
            callData: abi.encodeCall(TrustedForwarder.setTrustedForwarder, (address(hook)))
        });

        instance.getExecOps({
            executions: execution,
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        token = new MockERC20("usdc", "usdc", 18);
        token.mint(instance.account, 100 ether);
        vm.deal(instance.account, 1000 ether);

        bytes memory initData = _getInitData(true);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hook),
            data: initData
        });
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
            address(subHook6),
            address(subHook7)
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
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier expectHookCall(address hookAddress) {
        vm.expectCall(
            address(hookAddress), abi.encodeWithSelector(IERC7579Hook.preCheck.selector), 1
        );
        vm.expectCall(
            address(hookAddress), abi.encodeWithSelector(IERC7579Hook.postCheck.selector), 1
        );
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_ShouldCallPreCheck() public {
        Execution[] memory execution = new Execution[](3);
        execution[0] = Execution({
            target: address(target),
            value: 1 wei,
            callData: abi.encodeCall(MockTarget.set, (1336))
        });

        execution[1] = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (makeAddr("receiver"), 100))
        });

        execution[2] = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (makeAddr("receiver"), 100))
        });

        UserOpData memory userOpData = instance.getExecOps({
            executions: execution,
            txValidator: address(instance.defaultValidator)
        });
        userOpData.execUserOps();
    }

    function test_ShouldNotRevert() external {
        // It should never revert Hook

        address target = address(1);
        uint256 value = 1 wei;
        bytes memory callData = "";

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: callData,
            txValidator: address(instance.defaultValidator)
        });

        // Execute the userOp
        userOpData.execUserOps();
    }

    function test_ShouldRevert_InPreCheck() external {
        // It should never revert Hook

        address target = address(1);
        uint256 value = 1 wei;
        bytes memory callData = "";

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: callData,
            txValidator: address(instance.defaultValidator)
        });

        ModeSelector modeSelector = ModeSelector.wrap(bytes4(keccak256(abi.encode("revert"))));

        ModeCode mode = ModeLib.encode({
            callType: CALLTYPE_SINGLE,
            execType: EXECTYPE_DEFAULT,
            mode: modeSelector,
            payload: ModePayload.wrap(bytes22(0))
        });
        bytes memory data = abi.encodePacked(target, value, callData);
        bytes memory encodedCallData = abi.encodeCall(IERC7579Account.execute, (mode, data));

        userOpData.userOp.callData = encodedCallData;

        instance.expect4337Revert();

        // Execute the userOp
        userOpData.execUserOps();
    }

    function test_ShouldRevert_InPostCheck() external {
        // It should never revert Hook

        address target = address(1);
        uint256 value = 1 wei;
        bytes memory callData = "";

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: callData,
            txValidator: address(instance.defaultValidator)
        });

        ModeSelector modeSelector = ModeSelector.wrap(bytes4(keccak256(abi.encode("revertPost"))));

        ModeCode mode = ModeLib.encode({
            callType: CALLTYPE_SINGLE,
            execType: EXECTYPE_DEFAULT,
            mode: modeSelector,
            payload: ModePayload.wrap(bytes22(0))
        });
        bytes memory data = abi.encodePacked(target, value, callData);
        bytes memory encodedCallData = abi.encodeCall(IERC7579Account.execute, (mode, data));

        userOpData.userOp.callData = encodedCallData;

        instance.expect4337Revert();

        // Execute the userOp
        userOpData.execUserOps();
    }

    function test_DeadmanSwitch() public expectHookCall(address(deadmanSwitch)) {
        address[] memory prevHooks = hook.getHooks(address(instance.account));
        instance.getExecOps({
            target: address(hook),
            value: 0,
            callData: abi.encodeCall(HookMultiPlexer.addHook, (address(deadmanSwitch), HookType.GLOBAL)),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory newHooks = hook.getHooks(address(instance.account));
        assertEq(prevHooks.length + 1, newHooks.length);

        instance.getExecOps({
            target: address(2),
            value: 1 wei,
            callData: "",
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        (uint48 lastAccess,,) = deadmanSwitch.config(instance.account);
        assertEq(lastAccess, block.timestamp);
    }

    function test_RegistryHook() public expectHookCall(address(registryHook)) {
        address[] memory prevHooks = hook.getHooks(address(instance.account));
        instance.getExecOps({
            target: address(hook),
            value: 0,
            callData: abi.encodeCall(
                HookMultiPlexer.addSigHook,
                (address(registryHook), IERC7579Account.installModule.selector, HookType.SIG)
            ),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory newHooks = hook.getHooks(address(instance.account));
        assertEq(prevHooks.length + 1, newHooks.length);

        address mockModule = address(24);
        vm.etch(mockModule, mockModuleCode.code);

        vm.expectCall(
            address(instance.aux.registry),
            abi.encodeWithSelector(
                0x529562a1, address(instance.account), mockModule, MODULE_TYPE_VALIDATOR
            )
        );

        instance.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: mockModule, data: "" });
    }

    function test_ColdStorageHook() public expectHookCall(address(coldStorage)) {
        address[] memory prevHooks = hook.getHooks(address(instance.account));
        instance.getExecOps({
            target: address(hook),
            value: 0,
            callData: abi.encodeCall(
                HookMultiPlexer.addSigHook,
                (address(coldStorage), IERC7579Account.executeFromExecutor.selector, HookType.SIG)
            ),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory newHooks = hook.getHooks(address(instance.account));
        assertEq(prevHooks.length + 1, newHooks.length);

        address mockModule = address(24);
        vm.etch(mockModule, mockModuleCode.code);

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: mockModule, data: "" });

        vm.prank(mockModule);

        IERC7579Account(instance.account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(
                address(coldStorage),
                0,
                abi.encodeCall(
                    ColdStorageHook.requestTimelockedExecution,
                    (Execution({ target: address(1), value: 1 wei, callData: "" }), 0)
                )
            )
        );
    }

    function test_ColdStorageHook_RevertWhen_ColdStorageReverts() public {
        address[] memory prevHooks = hook.getHooks(address(instance.account));
        instance.getExecOps({
            target: address(hook),
            value: 0,
            callData: abi.encodeCall(
                HookMultiPlexer.addSigHook,
                (address(coldStorage), IERC7579Account.executeFromExecutor.selector, HookType.SIG)
            ),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory newHooks = hook.getHooks(address(instance.account));
        assertEq(prevHooks.length + 1, newHooks.length);

        address mockModule = address(24);
        vm.etch(mockModule, mockModuleCode.code);

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: mockModule, data: "" });

        vm.expectRevert();
        vm.prank(mockModule);
        IERC7579Account(instance.account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(), ExecutionLib.encodeSingle(address(2), 1 wei, "")
        );
    }
}
