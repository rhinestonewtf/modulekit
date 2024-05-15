// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Safe7579DCUtil, Safe7579DCUtilSetup } from "./SetupDCUtil.sol";
import { BatchedExecUtil } from "../utils/DCUtil.sol";
import { Execution } from "../interfaces/IERC7579Account.sol";
import { ISafe } from "../interfaces/ISafe.sol";

/**
 * Abstraction layer for executions.
 * @dev All interactions with modules must originate from msg.sender == SafeProxy. This entails
 * avoiding direct calls by the Safe7579 Adapter for actions like onInstall on modules or
 * validateUserOp on validator modules, and utilizing the Safe's execTransactionFromModule feature
 * instead.
 * @dev Since Safe7579 offers features like TryExecute for batched executions, rewriting and
 * verifying execution success across the codebase can be challenging and error-prone. These
 * functions serve to interact with modules and external contracts.
 */
abstract contract ExecutionHelper is Safe7579DCUtilSetup {
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
    /**
     * Helper function to facilitate batched executions. Since Safe accounts do not support batched
     * executions natively, we nudge the safe to delegatecall to ./utils/DCUTIL.sol, which then
     * makes a multicall. This is to save on gas
     */
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
    /**
     * Helper function to facilitate batched executions. Since Safe accounts do not support batched
     * executions natively, we nudge the safe to delegatecall to ./utils/DCUTIL.sol, which then
     * makes a multicall. This is to save on gas
     */
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

    /**
     * Helper function to facilitate batched executions. Since Safe accounts do not support batched
     * executions natively, we nudge the safe to delegatecall to ./utils/DCUTIL.sol, which then
     * makes a multicall. This is to save on gas
     */
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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     STATICCALL TRICK                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Safe account does not natively implement Enum.Operation.StaticCall,
     * using a trick with simulateAndRevert to execute a staticcall.
     * @param safe Safe account to execute the staticcall
     * @param target Target contract to staticcall
     * @param callData Data to be passed to the target contract
     */
    function _staticcallReturn(
        ISafe safe,
        address target,
        bytes memory callData
    )
        internal
        view
        returns (bytes memory result)
    {
        bytes memory staticCallData = abi.encodeCall(Safe7579DCUtil.staticCall, (target, callData));
        bytes memory simulationCallData =
            abi.encodeCall(ISafe.simulateAndRevert, (address(UTIL), staticCallData));

        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            pop(
                staticcall(
                    gas(),
                    safe,
                    add(simulationCallData, 0x20),
                    mload(simulationCallData),
                    0x00,
                    0x20
                )
            )

            let responseSize := sub(returndatasize(), 0x20)
            result := mload(0x40)
            mstore(0x40, add(result, responseSize))
            returndatacopy(result, 0x20, responseSize)

            if iszero(mload(0x00)) { revert(add(result, 0x20), mload(result)) }
        }
    }
}
