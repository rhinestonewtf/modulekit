// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IExecution as IERC7579Execution } from "erc7579/interfaces/IMSA.sol";

library ERC7579ExecutorLib {
    function execute(
        address account,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bytes memory result)
    {
        return IERC7579Execution(account).executeFromExecutor(to, value, data);
    }

    function execute(
        address account,
        IERC7579Execution.Execution[] memory execs
    )
        internal
        returns (bytes[] memory results)
    {
        return IERC7579Execution(account).executeBatchFromExecutor(execs);
    }
}
