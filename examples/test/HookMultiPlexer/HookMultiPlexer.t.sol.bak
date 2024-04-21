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

import "erc7579/lib/ModeLib.sol";

contract HookMultiPlexerTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;
    HookMultiPlexer internal hook;
    MockHook internal subHook1;

    function setUp() public {
        vm.warp(100);

        instance = makeAccountInstance("Account");

        hook = new HookMultiPlexer();
        vm.label(address(hook), "HookMultiPlexer");
        subHook1 = new MockHook();
        vm.label(address(subHook1), "SubHook1");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hook),
            data: abi.encode(subHook1)
        });
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

    // function test_shouldRevert__inPostCheck() external {
    //     // It should never revert Hook

    //     address target = address(1);
    //     uint256 value = 1 wei;
    //     bytes memory callData = "";

    //     UserOpData memory userOpData = instance.getExecOps({
    //         target: target,
    //         value: value,
    //         callData: callData,
    //         txValidator: address(defaultValidator)
    //     });

    //     ModeSelector modeSelector =
    // ModeSelector.wrap(bytes4(keccak256(abi.encode("revertPost"))));

    //     ModeCode mode = ModeLib.encode({
    //         callType: CALLTYPE_SINGLE,
    //         execType: EXECTYPE_DEFAULT,
    //         mode: modeSelector,
    //         payload: ModePayload.wrap(bytes22(0))
    //     });
    //     bytes memory data = abi.encodePacked(target, value, callData);
    //     bytes memory encodedCallData = abi.encodeCall(IERC7579Account.execute, (mode, data));

    //     userOpData.userOp.callData = encodedCallData;

    //     instance.expect4337Revert();

    //     // Execute the userOp
    //     userOpData.execUserOps();
    // }
}
