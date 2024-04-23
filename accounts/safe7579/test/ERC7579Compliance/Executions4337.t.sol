// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.t.sol";
import {
    ExecType,
    ModeCode,
    ModeLib,
    ModePayload,
    MODE_DEFAULT,
    EXECTYPE_DEFAULT,
    EXECTYPE_TRY,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL
} from "erc7579/lib/ModeLib.sol";

contract Executions4337Test is BaseTest {
    function setUp() public virtual override {
        super.setUp();
        installUnitTestAsModule();
    }

    function test_WhenExecutingOnValidTarget() external asEntryPoint {
        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.set, 1337);
        // It should pass
        account.execute(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(target), uint256(0), setValueOnTarget)
        );
        assertEq(target.value(), 1337);

        setValueOnTarget = abi.encodeCall(MockTarget.set, 1336);
        Execution[] memory executions = new Execution[](2);
        MockTarget target2 = new MockTarget();
        executions[0] =
            Execution({ target: address(target2), value: 0, callData: setValueOnTarget });
        executions[1] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });
        account.execute(ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions));
        assertEq(target2.value(), 1336);
        assertEq(target.value(), 1336);
    }

    function test_WhenExecutingSingleOnInvalidTarget() external asEntryPoint {
        // It should revert
        vm.expectRevert();
        account.execute(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(target), uint256(0), hex"4141414141414141")
        );
    }

    function test_WhenTryExecutingOnValidTarget() external asEntryPoint {
        bytes memory setValueOnTarget = abi.encodeCall(MockTarget.set, 1337);
        // It should pass
        account.execute(
            ModeLib.encode(
                CALLTYPE_SINGLE, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(bytes22(0))
            ),
            ExecutionLib.encodeSingle(address(target), uint256(0), hex"41414145")
        );

        setValueOnTarget = abi.encodeCall(MockTarget.set, 1338);
        Execution[] memory executions = new Execution[](2);
        // this one will fail
        executions[0] = Execution({ target: address(target), value: 0, callData: hex"41414141" });
        // this one will execute
        executions[1] = Execution({ target: address(target), value: 0, callData: setValueOnTarget });
        account.execute(
            ModeLib.encode(CALLTYPE_BATCH, EXECTYPE_TRY, MODE_DEFAULT, ModePayload.wrap(bytes22(0))),
            ExecutionLib.encodeBatch(executions)
        );

        assertEq(target.value(), 1338);
    }
}
