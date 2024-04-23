// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// import "erc7579/lib/ModeLib.sol";
// import "erc7579/lib/ExecutionLib.sol";
import "./Launchpad.t.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";

import "forge-std/console2.sol";

contract Safe7579Test is LaunchpadBase {
    function setUp() public override {
        super.setUp();
        target = new MockTarget();
    }

    function test_execSingle() public {
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

    function test_execBatch() public {
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
        defaultExecutor.executeViaAccount(
            IERC7579Account(address(safe)),
            address(target),
            0,
            abi.encodeWithSelector(MockTarget.set.selector, 1337)
        );
    }

    function test_execBatchFromExecutor() public {
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
}
