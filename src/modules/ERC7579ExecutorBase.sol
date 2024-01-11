// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Executor, IERC7579Execution } from "../external/ERC7579.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";

abstract contract ERC7579ExecutorBase is IERC7579Executor, ERC7579ModuleBase {
    function _execute(
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

    function _execute(
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bytes memory result)
    {
        return IERC7579Execution(msg.sender).executeFromExecutor(to, value, data);
    }

    function _execute(
        address account,
        IERC7579Execution.Execution[] memory execs
    )
        internal
        returns (bytes[] memory results)
    {
        return IERC7579Execution(account).executeBatchFromExecutor(execs);
    }

    function _execute(IERC7579Execution.Execution[] memory execs)
        internal
        returns (bytes[] memory results)
    {
        return IERC7579Execution(msg.sender).executeBatchFromExecutor(execs);
    }
}
