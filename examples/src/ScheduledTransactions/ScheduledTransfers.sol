// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Account, Execution } from "modulekit/src/Accounts.sol";
import { SchedulingBase } from "./SchedulingBase.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";

contract ScheduledTransfers is SchedulingBase {
    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function executeOrder(uint256 jobId) external override canExecute(jobId) {
        ExecutionConfig storage executionConfig = _executionLog[msg.sender][jobId];

        Execution memory execution = abi.decode(executionConfig.executionData, (Execution));

        executionConfig.lastExecutionTime = uint48(block.timestamp);
        executionConfig.numberOfExecutionsCompleted += 1;

        IERC7579Account(msg.sender).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(execution.target, execution.value, execution.callData)
        );

        emit ExecutionTriggered(msg.sender, jobId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure virtual returns (string memory) {
        return "Scheduled Transfers";
    }

    function version() external pure virtual returns (string memory) {
        return "0.0.1";
    }
}
