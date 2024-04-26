// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "modulekit/src/ModuleKit.sol";
import "modulekit/src/Helpers.sol";
import "modulekit/src/Core.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_HOOK,
    IERC7579Account
} from "modulekit/src/external/ERC7579.sol";

import { HookMultiPlexer } from "src/HookMultiPlexer/HookMultiPlexer.sol";
import "forge-std/interfaces/IERC20.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { MockHook } from "test/mocks/MockHook.sol";
import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";

import "erc7579/lib/ModeLib.sol";
import { MockTarget } from "modulekit/src/mocks/MockTarget.sol";
import "forge-std/interfaces/IERC20.sol";
import "src/HookMultiPlexer/DataTypes.sol";

contract HookMultiPlexerTest is RhinestoneModuleKit, Test, IERC7579Hook {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;
    HookMultiPlexer internal hook;
    MockHook internal subHook1;
    MockTarget internal target;
    MockERC20 internal token;

    uint256 preCheckCalled;
    uint256 postCheckCalled;

    modifier requireHookCall(uint256 expected) {
        preCheckCalled = 0;
        postCheckCalled = 0;
        _;
        assertEq(preCheckCalled, expected);
        assertEq(postCheckCalled, expected);
    }

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    {
        preCheckCalled++;
    }

    function postCheck(bytes calldata hookData) external {
        postCheckCalled++;
    }

    function setUp() public {
        vm.warp(100);

        instance = makeAccountInstance("Account");
        target = new MockTarget();

        hook = new HookMultiPlexer();
        subHook1 = new MockHook();
        vm.label(address(subHook1), "SubHook1");

        token = new MockERC20("usdc", "usdc", 18);
        token.mint(instance.account, 100 ether);
        vm.deal(instance.account, 1000 ether);

        address[] memory globalHooks = new address[](1);
        globalHooks[0] = address(subHook1);
        address[] memory valueHooks = new address[](0);
        // valueHooks[0] = address(address(this));
        address[] memory _targetHooks = new address[](1);
        _targetHooks[0] = address(address(this));
        SigHookInit[] memory targetHooks = new SigHookInit[](2);
        targetHooks[0] = SigHookInit({ sig: IERC20.transfer.selector, subHooks: globalHooks });
        targetHooks[1] = SigHookInit({ sig: IERC20.transfer.selector, subHooks: _targetHooks });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hook),
            data: abi.encode(globalHooks, valueHooks, new SigHookInit[](0), targetHooks)
        });
    }

    function test_shouldCallPreCheck() public requireHookCall(1) {
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

    // function test_shouldNotRevert() external {
    //     // It should never revert Hook
    //
    //     address target = address(1);
    //     uint256 value = 1 wei;
    //     bytes memory callData = "";
    //
    //     UserOpData memory userOpData = instance.getExecOps({
    //         target: target,
    //         value: value,
    //         callData: callData,
    //         txValidator: address(defaultValidator)
    //     });
    //
    //     // Execute the userOp
    //     userOpData.execUserOps();
    // }
    //
    // function test_shouldRevert__inPreCheck() external {
    //     // It should never revert Hook
    //
    //     address target = address(1);
    //     uint256 value = 1 wei;
    //     bytes memory callData = "";
    //
    //     UserOpData memory userOpData = instance.getExecOps({
    //         target: target,
    //         value: value,
    //         callData: callData,
    //         txValidator: address(defaultValidator)
    //     });
    //
    //     ModeSelector modeSelector = ModeSelector.wrap(bytes4(keccak256(abi.encode("revert"))));
    //
    //     ModeCode mode = ModeLib.encode({
    //         callType: CALLTYPE_SINGLE,
    //         execType: EXECTYPE_DEFAULT,
    //         mode: modeSelector,
    //         payload: ModePayload.wrap(bytes22(0))
    //     });
    //     bytes memory data = abi.encodePacked(target, value, callData);
    //     bytes memory encodedCallData = abi.encodeCall(IERC7579Account.execute, (mode, data));
    //
    //     userOpData.userOp.callData = encodedCallData;
    //
    //     instance.expect4337Revert();
    //
    //     // Execute the userOp
    //     userOpData.execUserOps();
    // }
    //
    // // function test_shouldRevert__inPostCheck() external {
    // //     // It should never revert Hook
    //
    // //     address target = address(1);
    // //     uint256 value = 1 wei;
    // //     bytes memory callData = "";
    //
    // //     UserOpData memory userOpData = instance.getExecOps({
    // //         target: target,
    // //         value: value,
    // //         callData: callData,
    // //         txValidator: address(defaultValidator)
    // //     });
    //
    // //     ModeSelector modeSelector =
    // // ModeSelector.wrap(bytes4(keccak256(abi.encode("revertPost"))));
    //
    // //     ModeCode mode = ModeLib.encode({
    // //         callType: CALLTYPE_SINGLE,
    // //         execType: EXECTYPE_DEFAULT,
    // //         mode: modeSelector,
    // //         payload: ModePayload.wrap(bytes22(0))
    // //     });
    // //     bytes memory data = abi.encodePacked(target, value, callData);
    // //     bytes memory encodedCallData = abi.encodeCall(IERC7579Account.execute, (mode, data));
    //
    // //     userOpData.userOp.callData = encodedCallData;
    //
    // //     instance.expect4337Revert();
    //
    // //     // Execute the userOp
    // //     userOpData.execUserOps();
    // // }

    function isInitialized(address smartAccount) public view returns (bool) {
        return true;
    }

    function onInstall(bytes calldata) external { }
    function onUninstall(bytes calldata) external { }
    function isModuleType(uint256) external view returns (bool) { }
}
