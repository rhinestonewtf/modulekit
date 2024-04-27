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
    IERC7579Account
} from "modulekit/src/external/ERC7579.sol";

import { HookMultiplexer } from "src/HookMultiplexer/HookMultiplexer.sol";
import "forge-std/interfaces/IERC20.sol";
import { MockHook } from "test/mocks/MockHook.sol";
import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";

import "erc7579/lib/ModeLib.sol";
import { MockTarget } from "modulekit/src/mocks/MockTarget.sol";
import "forge-std/interfaces/IERC20.sol";
import "src/HookMultiplexer/DataTypes.sol";
import { Solarray } from "solarray/Solarray.sol";
import { LibSort } from "solady/utils/LibSort.sol";

contract HookMultiplexerIntegrationTest is BaseIntegrationTest {
    using LibSort for address[];
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    HookMultiplexer internal hook;

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

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public override {
        BaseIntegrationTest.setUp();

        vm.warp(100);

        target = new MockTarget();

        hook = new HookMultiplexer(instance.aux.registry);
        subHook1 = new MockHook();
        subHook2 = new MockHook();
        subHook3 = new MockHook();
        subHook4 = new MockHook();
        subHook5 = new MockHook();
        subHook6 = new MockHook();
        subHook7 = new MockHook();
        subHook8 = new MockHook();

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
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_shouldCallPreCheck() public {
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

        UserOpData memory userOpData =
            instance.getExecOps({ executions: execution, txValidator: address(defaultValidator) });
        userOpData.execUserOps();
    }

    function test_shouldNotRevert() external {
        // It should never revert Hook

        address target = address(1);
        uint256 value = 1 wei;
        bytes memory callData = "";

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: callData,
            txValidator: address(defaultValidator)
        });

        // Execute the userOp
        userOpData.execUserOps();
    }

    function test_shouldRevert__inPreCheck() external {
        // It should never revert Hook

        address target = address(1);
        uint256 value = 1 wei;
        bytes memory callData = "";

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: callData,
            txValidator: address(defaultValidator)
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

    function test_shouldRevert__inPostCheck() external {
        // It should never revert Hook

        address target = address(1);
        uint256 value = 1 wei;
        bytes memory callData = "";

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: callData,
            txValidator: address(defaultValidator)
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
}
