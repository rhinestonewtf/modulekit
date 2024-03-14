// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "erc7579/interfaces/IERC7579Account.sol";
import "erc7579/lib/ModeLib.sol";
import "erc7579/lib/ExecutionLib.sol";
import { TestBaseUtil, MockTarget, MockFallback } from "./Base.t.sol";

import "forge-std/console2.sol";

CallType constant CALLTYPE_STATIC = CallType.wrap(0xFE);

contract Safe7579Test is TestBaseUtil {
    MockTarget target;

    function setUp() public override {
        super.setUp();
        target = new MockTarget();
        deal(address(safe), 1 ether);
    }

    modifier alreadyInitialized(bool initNow) {
        if (initNow) {
            test_initializeAccount();
        }
        _;
    }

    function test_initializeAccount() public {
        PackedUserOperation memory userOp =
            getDefaultUserOp(address(safe), address(defaultValidator));

        // Create calldata for the account to execute
        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.set, 777);

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata = abi.encodeCall(
            IERC7579Account.execute,
            (
                ModeLib.encodeSimpleSingle(),
                ExecutionLib.encodeSingle(address(target), uint256(0), setValueOnTarget)
            )
        );
        userOp.initCode = userOpInitCode;
        userOp.callData = userOpCalldata;
        // Create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Send the userOp to the entrypoint
        entrypoint.handleOps(userOps, payable(address(0x69)));

        // Assert that the value was set ie that execution was successful
        assertTrue(target.value() == 777);
        userOpInitCode = "";
    }

    function test_execSingle(bool withInitializedAccount)
        public
        alreadyInitialized(withInitializedAccount)
    {
        // Create calldata for the account to execute
        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.set, 1337);

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata = abi.encodeCall(
            IERC7579Account.execute,
            (
                ModeLib.encodeSimpleSingle(),
                ExecutionLib.encodeSingle(address(target), uint256(0), setValueOnTarget)
            )
        );

        PackedUserOperation memory userOp =
            getDefaultUserOp(address(safe), address(defaultValidator));
        userOp.initCode = userOpInitCode;
        userOp.callData = userOpCalldata;

        // Create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Send the userOp to the entrypoint
        entrypoint.handleOps(userOps, payable(address(0x69)));

        // Assert that the value was set ie that execution was successful
        assertTrue(target.value() == 1337);
    }

    function test_execBatch(bool withInitializedAccount)
        public
        alreadyInitialized(withInitializedAccount)
    {
        // Create calldata for the account to execute
        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.set, 1337);
        address target2 = address(0x420);
        uint256 target2Amount = 1 wei;

        // Create the executions
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });
        executions[1] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });

        // Encode the call into the calldata for the userOp
        bytes memory userOpCalldata = abi.encodeCall(
            IERC7579Account.execute,
            (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions))
        );

        // Create the userOp and add the data
        PackedUserOperation memory userOp =
            getDefaultUserOp(address(safe), address(defaultValidator));
        userOp.initCode = userOpInitCode;
        userOp.callData = userOpCalldata;

        // Create userOps array
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Send the userOp to the entrypoint
        entrypoint.handleOps(userOps, payable(address(0x69)));

        // Assert that the value was set ie that execution was successful
        assertTrue(target.value() == 1337);
    }

    function test_execViaExecutor() public {
        test_initializeAccount();
        defaultExecutor.executeViaAccount(
            IERC7579Account(address(safe)),
            address(target),
            0,
            abi.encodeWithSelector(MockTarget.set.selector, 1337)
        );
    }

    function test_execBatchFromExecutor() public {
        test_initializeAccount();
        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.set, 1338);
        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });
        executions[1] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });
        bytes[] memory ret = defaultExecutor.execBatch({
            account: IERC7579Account(address(safe)),
            execs: executions
        });

        assertEq(ret.length, 2);
        assertEq(abi.decode(ret[0], (uint256)), 1338);
    }

    function test_fallback() public {
        test_initializeAccount();
        MockFallback _fallback = new MockFallback();
        vm.prank(address(safe));
        IERC7579Account(address(safe)).installModule(
            3, address(_fallback), abi.encode(MockFallback.target.selector, CALLTYPE_SINGLE, "")
        );
        (uint256 ret, address msgSender, address context) = MockFallback(address(safe)).target(1337);

        assertEq(ret, 1337);
        assertEq(msgSender, address(safe));
        assertEq(context, address(this));

        vm.prank(address(safe));
        IERC7579Account(address(safe)).uninstallModule(
            3, address(_fallback), abi.encode(MockFallback.target.selector, CALLTYPE_SINGLE, "")
        );
        // vm.prank(address(safe));
        // IERC7579Account(address(safe)).installModule(
        //     3, address(_fallback), abi.encode(MockFallback.target.selector, CALLTYPE_STATIC, "")
        // );
        // (ret, msgSender, context) = MockFallback(address(safe)).target(1337);
        // assertEq(ret, 1337);
        // assertEq(msgSender, address(safe7579));
        // assertEq(context, address(safe));

        vm.prank(address(safe));
        IERC7579Account(address(safe)).installModule(
            3,
            address(_fallback),
            abi.encode(MockFallback.target2.selector, CALLTYPE_DELEGATECALL, "")
        );
        (uint256 _ret, address _this, address _msgSender) =
            MockFallback(address(safe)).target2(1337);

        assertEq(_ret, 1337);
        assertEq(_this, address(safe));
    }
}
