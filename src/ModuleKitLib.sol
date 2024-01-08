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

library ModuleKitArray {
    function executions(IERC7579Execution.Execution memory _1)
        internal
        pure
        returns (IERC7579Execution.Execution[] memory array)
    {
        array = new IERC7579Execution.Execution[](1);
        array[0] = _1;
    }

    function executions(
        IERC7579Execution.Execution memory _1,
        IERC7579Execution.Execution memory _2
    )
        internal
        pure
        returns (IERC7579Execution.Execution[] memory array)
    {
        array = new IERC7579Execution.Execution[](2);
        array[0] = _1;
        array[1] = _2;
    }

    function executions(
        IERC7579Execution.Execution memory _1,
        IERC7579Execution.Execution memory _2,
        IERC7579Execution.Execution memory _3
    )
        internal
        pure
        returns (IERC7579Execution.Execution[] memory array)
    {
        array = new IERC7579Execution.Execution[](3);
        array[0] = _1;
        array[1] = _2;
        array[2] = _3;
    }

    function executions(
        IERC7579Execution.Execution memory _1,
        IERC7579Execution.Execution memory _2,
        IERC7579Execution.Execution memory _3,
        IERC7579Execution.Execution memory _4
    )
        internal
        pure
        returns (IERC7579Execution.Execution[] memory array)
    {
        array = new IERC7579Execution.Execution[](4);
        array[0] = _1;
        array[1] = _2;
        array[2] = _3;
        array[3] = _4;
    }
}
