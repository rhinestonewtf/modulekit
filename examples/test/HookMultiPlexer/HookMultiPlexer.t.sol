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

contract HookMultiPlexerTest is RhinestoneModuleKit, Test, IERC7579Hook {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;
    HookMultiPlexer internal hook;
    MockHook internal subHook1;
    MockTarget internal target;

    bool preCheckCalled;
    bool postCheckCalled;

    modifier requireHookCall() {
        preCheckCalled = false;
        postCheckCalled = false;
        _;
        assertTrue(preCheckCalled);
        assertTrue(postCheckCalled);
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
        preCheckCalled = true;
    }

    function postCheck(bytes calldata hookData) external {
        postCheckCalled = true;
    }

    function setUp() public {
        vm.warp(100);

        instance = makeAccountInstance("Account");
        target = new MockTarget();

        hook = new HookMultiPlexer();
        subHook1 = new MockHook();
        vm.label(address(subHook1), "SubHook1");

        IERC7579Hook[] memory globalHooks = new IERC7579Hook[](2);
        globalHooks[0] = IERC7579Hook(subHook1);
        globalHooks[1] = IERC7579Hook(address(this));

        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hook),
            data: abi.encode(globalHooks, globalHooks, new IERC7579Hook[](0))
        });
    }

    function test_shouldCallPreCheck() public requireHookCall {
        address target = address(1);
        uint256 value = 1 wei;
        bytes memory callData = abi.encodeCall(MockTarget.set, (1337));

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: callData,
            txValidator: address(defaultValidator)
        });
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
