// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Safe7579DCUtilSetup } from "./SetupDCUtil.sol";
import { BatchedExecUtil } from "../utils/DCUtil.sol";
import { Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { ISafe } from "../interfaces/ISafe.sol";

contract ExecutionHelper is Safe7579DCUtilSetup {
    event TryExecutionFailed(ISafe safe, uint256 numberInBatch);
    event TryExecutionsFailed(ISafe safe, bool[] success);

    error ExecutionFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   EXEC - REVERT ON FAIL                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function _exec(ISafe safe, Execution[] calldata executions) internal {
        _delegatecall({
            safe: safe,
            target: UTIL,
            callData: abi.encodeCall(BatchedExecUtil.execute, executions)
        });
    }

    function _exec(ISafe safe, address target, uint256 value, bytes memory callData) internal {
        bool success = safe.execTransactionFromModule(target, value, callData, 0);
        if (!success) revert ExecutionFailed();
    }

    function _delegatecall(ISafe safe, address target, bytes memory callData) internal {
        bool success = safe.execTransactionFromModule(target, 0, callData, 1);
        if (!success) revert ExecutionFailed();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*             EXEC - REVERT ON FAIL & Return Values          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function _execReturn(
        ISafe safe,
        Execution[] calldata executions
    )
        internal
        returns (bytes[] memory retDatas)
    {
        bytes memory tmp = _delegatecallReturn({
            safe: safe,
            target: UTIL,
            callData: abi.encodeCall(BatchedExecUtil.executeReturn, executions)
        });
        retDatas = abi.decode(tmp, (bytes[]));
    }

    function _execReturn(
        ISafe safe,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes memory retData)
    {
        bool success;
        (success, retData) = safe.execTransactionFromModuleReturnData(target, value, callData, 0);
        if (!success) revert ExecutionFailed();
    }

    function _delegatecallReturn(
        ISafe safe,
        address target,
        bytes memory callData
    )
        internal
        returns (bytes memory retData)
    {
        bool success;
        (success, retData) = safe.execTransactionFromModuleReturnData(target, 0, callData, 1);
        if (!success) revert ExecutionFailed();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        EXEC - TRY                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function _tryExec(ISafe safe, Execution[] calldata executions) internal {
        _tryDelegatecall({
            safe: safe,
            target: UTIL,
            callData: abi.encodeCall(BatchedExecUtil.tryExecute, executions)
        });
    }

    function _tryExec(ISafe safe, address target, uint256 value, bytes memory callData) internal {
        bool success = safe.execTransactionFromModule(target, value, callData, 0);
        if (!success) emit TryExecutionFailed(safe, 0);
    }

    function _tryDelegatecall(ISafe safe, address target, bytes memory callData) internal {
        bool success = safe.execTransactionFromModule(target, 0, callData, 1);
        if (!success) emit TryExecutionFailed(safe, 0);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*              EXEC - TRY & Return Values                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _tryExecReturn(
        ISafe safe,
        Execution[] calldata executions
    )
        internal
        returns (bool[] memory success, bytes[] memory retDatas)
    {
        bytes memory tmp = _tryDelegatecallReturn({
            safe: safe,
            target: UTIL,
            callData: abi.encodeCall(BatchedExecUtil.tryExecuteReturn, executions)
        });
        (success, retDatas) = abi.decode(tmp, (bool[], bytes[]));
    }

    function _tryExecReturn(
        ISafe safe,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes memory retData)
    {
        bool success;
        (success, retData) = safe.execTransactionFromModuleReturnData(target, value, callData, 0);
        if (!success) emit TryExecutionFailed(safe, 0);
    }

    function _tryDelegatecallReturn(
        ISafe safe,
        address target,
        bytes memory callData
    )
        internal
        returns (bytes memory retData)
    {
        bool success;
        (success, retData) = safe.execTransactionFromModuleReturnData(target, 0, callData, 1);
        if (!success) emit TryExecutionFailed(safe, 0);
    }
}
