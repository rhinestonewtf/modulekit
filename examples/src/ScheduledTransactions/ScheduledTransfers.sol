// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Account } from "modulekit/src/Accounts.sol";
import { SchedulingBase } from "./SchedulingBase.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract ScheduledTransfers is SchedulingBase {
    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function executeOrder(uint256 jobId) external override canExecute(jobId) {
        ExecutionConfig storage executionConfig = _executionLog[msg.sender][jobId];

        executionConfig.lastExecutionTime = uint48(block.timestamp);
        executionConfig.numberOfExecutionsCompleted += 1;

        (address recipient, address token, uint256 amount) =
            abi.decode(executionConfig.executionData, (address, address, uint256));

        if (token == address(0)) {
            IERC7579Account(msg.sender).executeFromExecutor(
                ModeLib.encodeSimpleSingle(), ExecutionLib.encodeSingle(recipient, amount, "")
            );
        } else {
            IERC7579Account(msg.sender).executeFromExecutor(
                ModeLib.encodeSimpleSingle(),
                ExecutionLib.encodeSingle(
                    token, 0, abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
                )
            );
        }

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
