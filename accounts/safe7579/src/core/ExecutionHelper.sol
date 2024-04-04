// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { ISafe } from "../interfaces/ISafe.sol";
import {
    SimulateTxAccessor,
    Enum
} from "@safe-global/safe-contracts/contracts/accessors/SimulateTxAccessor.sol";

/**
 * @title Helper contract to execute transactions from a safe
 * All functions implemented in this contract check,
 * that the transaction was successful
 * @author zeroknots.eth
 */
abstract contract ExecutionHelper {
    error ExecutionFailed();

    SimulateTxAccessor private immutable SIMULATETX;

    constructor() {
        SIMULATETX = new SimulateTxAccessor();
    }

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
     * Safe does not implement Enum.Operation for staticcall.
     * we are using a trick, of nudging the Safe account to delegatecall to the SimulateTxAccessor,
     * and call simulate()
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
        returns (bytes memory returnData)
    {
        bool success;
        // this is the return data from the Safe.execTransactionFromModuleReturnData call. NOT the
        // simulation
        (success, returnData) = ISafe(safe).execTransactionFromModuleReturnData(
            address(SIMULATETX),
            0,
            abi.encodeCall(SIMULATETX.simulate, (target, value, callData, Enum.Operation.Call)),
            1
        );
        if (!success) revert ExecutionFailed();
        // decode according to simulate() return values
        (, success, returnData) = abi.decode(returnData, (uint256, bool, bytes));
        if (!success) revert ExecutionFailed();
    }
}
