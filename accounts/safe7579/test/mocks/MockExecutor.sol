// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Account, Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { MockExecutor as MockExecutorBase } from "@rhinestone/modulekit/src/mocks/MockExecutor.sol";

contract MockExecutor is MockExecutorBase {
    function executeViaAccount(
        IERC7579Account account,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        returns (bytes[] memory returnData)
    {
        return account.executeFromExecutor(
            ModeLib.encodeSimpleSingle(), ExecutionLib.encodeSingle(target, value, callData)
        );
    }

    function execBatch(
        IERC7579Account account,
        Execution[] calldata execs
    )
        external
        returns (bytes[] memory returnData)
    {
        return account.executeFromExecutor(
            ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(execs)
        );
    }
}
