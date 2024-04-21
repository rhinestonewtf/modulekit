// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC7579Account } from "modulekit/src/Accounts.sol";
import { SchedulingBase } from "modulekit/src/Modules.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

/**
 * @title ScheduledTransfers
 * @dev Module that allows users to schedule transfers to be executed at a later time
 * @author Rhinestone
 */
contract ScheduledTransfers is SchedulingBase {
    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Executes a scheduled transfer order
     *
     * @param jobId unique identifier for the job
     */
    function executeOrder(uint256 jobId) external override canExecute(jobId) {
        // get the execution config
        ExecutionConfig storage executionConfig = executionLog[msg.sender][jobId];

        // update the execution config
        executionConfig.lastExecutionTime = uint48(block.timestamp);
        executionConfig.numberOfExecutionsCompleted += 1;

        // decode from executionData: recipient, token and amount
        (address recipient, address token, uint256 amount) =
            abi.decode(executionConfig.executionData, (address, address, uint256));

        if (token == address(0)) {
            // execute native token transfer
            IERC7579Account(msg.sender).executeFromExecutor(
                ModeLib.encodeSimpleSingle(), ExecutionLib.encodeSingle(recipient, amount, "")
            );
        } else {
            // execute ERC20 token transfer
            IERC7579Account(msg.sender).executeFromExecutor(
                ModeLib.encodeSimpleSingle(),
                ExecutionLib.encodeSingle(
                    token, 0, abi.encodeCall(IERC20.transfer, (recipient, amount))
                )
            );
        }

        // emit the ExecutionTriggered event
        emit ExecutionTriggered(msg.sender, jobId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Returns the name of the module
     *
     * @return name of the module
     */
    function name() external pure virtual returns (string memory) {
        return "ScheduledTransfers";
    }

    /**
     * Returns the version of the module
     *
     * @return version of the module
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
