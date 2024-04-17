// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ISafe } from "../interfaces/ISafe.sol";

import {
    CallType,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL
} from "erc7579/lib/ModeLib.sol";

error ExecutionFailed();

event TryExecutionFailed(ISafe safe, uint256 numberInBatch);

error UnsupportedCallType(CallType calltype);

library ExecOnSafeLib {
    function exec(ISafe safe, address target, uint256 value, bytes memory callData) internal {
        bool success = safe.execTransactionFromModule(target, value, callData, 0);
        if (!success) revert ExecutionFailed();
    }

    function exec(ISafe safe, Execution[] calldata executions) internal {
        uint256 length = executions.length;
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];
            exec({
                safe: safe,
                target: execution.target,
                value: execution.value,
                callData: execution.callData
            });
        }
    }

    function execDelegateCall(ISafe safe, address target, bytes memory callData) internal {
        bool success = safe.execTransactionFromModule(target, 0, callData, 1);
        if (!success) revert ExecutionFailed();
    }

    function execReturn(
        ISafe safe,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes memory returnData)
    {
        bool success;
        (success, returnData) = safe.execTransactionFromModuleReturnData(target, value, callData, 0);
        if (!success) revert ExecutionFailed();
    }

    function execReturn(
        ISafe safe,
        Execution[] calldata executions
    )
        internal
        returns (bytes[] memory returnDatas)
    {
        uint256 length = executions.length;
        returnDatas = new bytes[](length);
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];
            returnDatas[i] = execReturn({
                safe: safe,
                target: execution.target,
                value: execution.value,
                callData: execution.callData
            });
        }
    }

    function execDelegateCallReturn(
        ISafe safe,
        address target,
        bytes memory callData
    )
        internal
        returns (bytes memory returnData)
    {
        bool success;
        (success, returnData) = safe.execTransactionFromModuleReturnData(target, 0, callData, 1);
        if (!success) revert ExecutionFailed();
    }
}

library TryExecOnSafeLib {
    /**
     * Try Execute call on Safe
     * @dev This function will revert if the call fails
     * @param safe address of the safe
     * @param target address of the contract to call
     * @param value value of the transaction
     * @param callData data of the transaction
     */
    function tryExec(ISafe safe, address target, uint256 value, bytes memory callData) internal {
        bool success = safe.execTransactionFromModule(target, value, callData, 0);
        if (!success) emit TryExecutionFailed(safe, 0);
    }

    /**
     * Try Execute call on Safe, get return value from call
     * @dev This function will revert if the call fails
     * @param safe address of the safe
     * @param target address of the contract to call
     * @param value value of the transaction
     * @param callData data of the transaction
     * @return success boolean if the call was successful
     * @return returnData data returned from the call
     */
    function tryExecReturn(
        ISafe safe,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = safe.execTransactionFromModuleReturnData(target, value, callData, 0);
        if (!success) emit TryExecutionFailed(safe, 0);
    }

    /**
     * Try Execute call on Safe
     * @dev This function will revert if the call fails
     * @param safe address of the safe
     * @param executions ERC-7579 struct for batched executions
     */
    function tryExec(ISafe safe, Execution[] calldata executions) internal returns (bool success) {
        uint256 length = executions.length;
        success = true;
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];

            bool _success = safe.execTransactionFromModule(
                execution.target, execution.value, execution.callData, 0
            );
            if (_success == false) {
                emit TryExecutionFailed(safe, i);
                if (success == true) success = false;
            }
        }
    }

    function tryExecDelegateCall(ISafe safe, address target, bytes calldata callData) internal {
        bool success = safe.execTransactionFromModule(target, 0, callData, 1);
        if (!success) emit TryExecutionFailed(safe, 0);
    }

    function tryExecDelegateCallReturn(
        ISafe safe,
        address target,
        bytes calldata callData
    )
        internal
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = safe.execTransactionFromModuleReturnData(target, 0, callData, 1);
        if (!success) emit TryExecutionFailed(safe, 0);
    }

    /**
     * Execute call on Safe
     * @dev This function will revert if the call fails
     * @param safe address of the safe
     * @param executions ERC-7579 struct for batched executions
     * @return success boolean if the call was successful
     * @return returnDatas  array returned datas from the batched calls
     */
    function tryExecReturn(
        ISafe safe,
        Execution[] calldata executions
    )
        internal
        returns (bool success, bytes[] memory returnDatas)
    {
        uint256 length = executions.length;
        returnDatas = new bytes[](length);
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];

            bool _success = safe.execTransactionFromModule(
                execution.target, execution.value, execution.callData, 0
            );
            if (_success == false) {
                emit TryExecutionFailed(safe, i);
                if (success == true) success = false;
            }
        }
    }
}

import { IHook } from "erc7579/interfaces/IERC7579Module.sol";

library HookedExecOnSafeLib {
    using ExecOnSafeLib for ISafe;
    using TryExecOnSafeLib for ISafe;
    using ExecutionLib for bytes;

    function preHook(ISafe safe, address withHook) internal returns (bytes memory hookPreContext) {
        if (withHook == address(0)) return "";
        hookPreContext = abi.decode(
            safe.execReturn({
                target: withHook,
                value: 0,
                callData: abi.encodeCall(IHook.preCheck, (msg.sender, msg.value, msg.data))
            }),
            (bytes)
        );
    }

    function postHook(
        ISafe safe,
        address withHook,
        bytes memory hookPreContext,
        bool excutionSuccess,
        bytes memory executionReturnValue
    )
        internal
    {
        if (withHook == address(0)) return;
        safe.execReturn({
            target: withHook,
            value: 0,
            callData: abi.encodeCall(
                IHook.postCheck, (hookPreContext, excutionSuccess, executionReturnValue)
            )
        });
    }

    function hookedExec(
        bytes calldata executionCalldata,
        CallType callType,
        address hook
    )
        internal
        returns (bytes[] memory retDatas)
    {
        ISafe safe = ISafe(msg.sender);
        bool hookEnabled = hook != address(0);
        bytes memory preHookContext;
        if (hookEnabled) preHookContext = preHook(safe, hook);

        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = executionCalldata.decodeBatch();
            retDatas = safe.execReturn(executions);
        } else if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata callData) =
                executionCalldata.decodeSingle();
            retDatas = new bytes[](1);
            retDatas[0] = safe.execReturn(target, value, callData);
        } else if (callType == CALLTYPE_DELEGATECALL) {
            address target = address(bytes20(executionCalldata[:20]));
            bytes calldata callData = executionCalldata[20:];
            retDatas = new bytes[](1);
            retDatas[0] = safe.execDelegateCallReturn(target, callData);
        } else {
            revert UnsupportedCallType(callType);
        }
        if (hookEnabled) postHook(safe, hook, preHookContext, true, abi.encode(retDatas));
    }

    function hookedTryExec(
        bytes calldata executionCalldata,
        CallType callType,
        address hook
    )
        internal
        returns (bytes[] memory retDatas)
    {
        bool success;
        ISafe safe = ISafe(msg.sender);
        bytes memory preHookContext;
        preHookContext = preHook(safe, hook);

        if (callType == CALLTYPE_BATCH) {
            Execution[] calldata executions = executionCalldata.decodeBatch();
            (success, retDatas) = safe.tryExecReturn(executions);
        } else if (callType == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata callData) =
                executionCalldata.decodeSingle();
            retDatas = new bytes[](1);
            (success, retDatas[0]) = safe.tryExecReturn(target, value, callData);
        } else if (callType == CALLTYPE_DELEGATECALL) {
            address target = address(bytes20(executionCalldata[:20]));
            bytes calldata callData = executionCalldata[20:];
            retDatas = new bytes[](1);
            (success, retDatas[0]) = safe.tryExecDelegateCallReturn(target, callData);
        } else {
            revert UnsupportedCallType(callType);
        }
        postHook(safe, hook, preHookContext, true, abi.encode(retDatas));
    }
}

function _msgSender() pure returns (address sender) {
    // The assembly code is more direct than the Solidity version using `abi.decode`.
    /* solhint-disable no-inline-assembly */
    /// @solidity memory-safe-assembly
    assembly {
        sender := shr(96, calldataload(sub(calldatasize(), 20)))
    }
    /* solhint-enable no-inline-assembly */
}
