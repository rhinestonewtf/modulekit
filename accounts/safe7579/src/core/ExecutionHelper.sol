// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { ISafe } from "../interfaces/ISafe.sol";

/**
 * @title Helper contract to execute transactions from a safe
 * All functions implemented in this contract check,
 * that the transaction was successful
 * @author zeroknots.eth
 */
abstract contract ExecutionHelper {
    error ExecutionFailed();

    /**
     * Execute call on Safe
     * @dev This function will revert if the call fails
     * @param safe address of the safe
     * @param target address of the contract to call
     * @param value value of the transaction
     * @param callData data of the transaction
     */
    function _execute(
        address safe,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
    {
        bool success = ISafe(safe).execTransactionFromModule(target, value, callData, 0);
        if (!success) revert ExecutionFailed();
    }

    /**
     * Execute call on Safe, get return value from call
     * @dev This function will revert if the call fails
     * @param safe address of the safe
     * @param target address of the contract to call
     * @param value value of the transaction
     * @param callData data of the transaction
     * @return returnData data returned from the call
     */
    function _executeReturnData(
        address safe,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (bytes memory returnData)
    {
        bool success;
        (success, returnData) =
            ISafe(safe).execTransactionFromModuleReturnData(target, value, callData, 0);
        if (!success) revert ExecutionFailed();
    }

    /**
     * Execute call on Safe
     * @dev This function will revert if the call fails
     * @param safe address of the safe
     * @param executions ERC-7579 struct for batched executions
     */
    function _execute(address safe, Execution[] calldata executions) internal {
        uint256 length = executions.length;
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];
            _execute(safe, execution.target, execution.value, execution.callData);
        }
    }

    function _executeDelegateCall(address safe, address target, bytes calldata callData) internal {
        bool success = ISafe(safe).execTransactionFromModule(target, 0, callData, 1);
        if (!success) revert ExecutionFailed();
    }

    function _executeDelegateCallReturnData(
        address safe,
        address target,
        bytes calldata callData
    )
        internal
        returns (bytes memory returnData)
    {
        bool success;
        (success, returnData) =
            ISafe(safe).execTransactionFromModuleReturnData(target, 0, callData, 1);
        if (!success) revert ExecutionFailed();
    }

    /**
     * Execute call on Safe
     * @dev This function will revert if the call fails
     * @param safe address of the safe
     * @param executions ERC-7579 struct for batched executions
     * @return returnDatas  array returned datas from the batched calls
     */
    function _executeReturnData(
        address safe,
        Execution[] calldata executions
    )
        internal
        returns (bytes[] memory returnDatas)
    {
        uint256 length = executions.length;
        returnDatas = new bytes[](length);
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];
            returnDatas[i] =
                _executeReturnData(safe, execution.target, execution.value, execution.callData);
        }
    }

    /**
     * Execute staticcall on Safe, get return value from call
     * @dev This function will revert if the call fails
     * @param safe address of the safe
     * @param target address of the contract to call
     * @param value value of the transaction
     * @param callData data of the transaction
     * @return returnData data returned from the call
     */
    function _executeStaticReturnData(
        address safe,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        view
        returns (bytes memory returnData)
    {
        bool success;
        (success, returnData) = safe.staticcall(
            abi.encodeCall(ISafe.execTransactionFromModuleReturnData, (target, value, callData, 0))
        );
        if (!success) revert ExecutionFailed();
    }
}
