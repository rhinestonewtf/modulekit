// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "./modules/ERC7579ValidatorBase.sol";
import { ERC7579ExecutorBase } from "./modules/ERC7579ExecutorBase.sol";
import { ERC7579HookBase } from "./modules/ERC7579HookBase.sol";
import { ERC7579FallbackBase } from "./modules/ERC7579FallbackBase.sol";
import { IERC7579Execution } from "./ModuleKit.sol";

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
