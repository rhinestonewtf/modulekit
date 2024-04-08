// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "modulekit/src/ModuleKit.sol";
import "modulekit/src/Helpers.sol";
import "modulekit/src/Core.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import { MODULE_TYPE_VALIDATOR, MODULE_TYPE_HOOK } from "modulekit/src/external/ERC7579.sol";

import "src/DeadmanSwitch/DeadmanSwitch.sol";
import "forge-std/interfaces/IERC20.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

contract DeadmanSwitchTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;
    DeadmanSwitch internal dms;

    Account internal nominee;
    MockERC20 internal token;
    uint48 timeout;

    function setUp() public {
        vm.warp(100);

        instance = makeAccountInstance("Deadman");
        nominee = makeAccount("Nominee");
        token = new MockERC20("USDC", "USDC", 18);
        vm.label(address(token), "USDC");
        token.mint(instance.account, 1_000_000);

        dms = new DeadmanSwitch();

        timeout = uint48(block.timestamp + 128 days);
        bytes memory initData = abi.encode(nominee.addr, timeout);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(dms),
            data: initData
        });
        instance.installModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(dms), data: "" });
    }

    function test_ShouldNeverRevertHook() external {
        // It should never revert Hook

        instance.exec({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (makeAddr("somebody"), 1000))
        });

        vm.warp(timeout + 1 days);

        instance.exec({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (makeAddr("somebody"), 1000))
        });

        assertEq(token.balanceOf(instance.account), 998_000);
        assertEq(token.balanceOf(makeAddr("somebody")), 2000);
    }

    function test_WhenAccountIsUsed() public {
        // It should set lastAccess
        vm.warp(block.timestamp + 1 days);
        uint256 lastAccess = block.timestamp;

        // It should never revert Hook

        instance.exec({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (makeAddr("somebody"), 1000))
        });

        assertEq(dms.lastAccess(instance.account), lastAccess);
    }

    function signHash(uint256 privKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, ECDSA.toEthSignedMessageHash(digest));
        return abi.encodePacked(r, s, v);
    }

    function test_WhenValidatorIsUsedAndTimeoutNotReached() external {
        test_WhenAccountIsUsed();

        uint256 balanceOfAccount = token.balanceOf(instance.account);
        UserOpData memory userOpData = instance.getExecOps({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (nominee.addr, balanceOfAccount)),
            txValidator: address(dms)
        });
        userOpData.userOp.signature = signHash(nominee.key, userOpData.userOpHash);
        address recover = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(userOpData.userOpHash), userOpData.userOp.signature
        );
        assertEq(recover, nominee.addr);
        vm.expectRevert();
        userOpData.execUserOps();

        // balance should not be changed
        assertEq(token.balanceOf(instance.account), balanceOfAccount);
    }

    function test_WhenValidatorIsUsedAndTimeoutIsReached() external {
        test_WhenAccountIsUsed();

        vm.warp(timeout + 2 days);

        uint256 balanceOfAccount = token.balanceOf(instance.account);

        UserOpData memory userOpData = instance.getExecOps({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (nominee.addr, balanceOfAccount)),
            txValidator: address(dms)
        });
        userOpData.userOp.signature = signHash(nominee.key, userOpData.userOpHash);
        address recover = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(userOpData.userOpHash), userOpData.userOp.signature
        );
        assertEq(recover, nominee.addr);
        userOpData.execUserOps();

        // balance should not be changed
        assertEq(token.balanceOf(instance.account), 0);
        assertEq(token.balanceOf(nominee.addr), balanceOfAccount);
    }
}
