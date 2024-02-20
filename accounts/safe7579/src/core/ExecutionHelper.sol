// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { Execution } from "erc7579/interfaces/IERC7579Account.sol";
import "../interfaces/ISafe.sol";

/**
 * @title Helper contract to execute transactions from a safe
 * All functions implemented in this contract check,
 * that the transaction was successful
 * @author zeroknots.eth
 */
abstract contract ExecutionHelper {
    error ExecutionFailed();

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

    function _execute(address safe, Execution[] calldata executions) internal {
        uint256 length = executions.length;
        for (uint256 i; i < length; i++) {
            _execute(safe, executions[i].target, executions[i].value, executions[i].callData);
        }
    }

    function _executeReturnData(
        address safe,
        Execution[] calldata executions
    )
        internal
        returns (bytes[] memory retData)
    {
        uint256 length = executions.length;
        retData = new bytes[](length);
        for (uint256 i; i < length; i++) {
            retData[i] = _executeReturnData(
                safe, executions[i].target, executions[i].value, executions[i].callData
            );
        }
    }
}
