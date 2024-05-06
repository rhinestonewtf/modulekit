// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "erc7579/lib/ModeLib.sol";
import "erc7579/lib/ExecutionLib.sol";
import "erc7579/interfaces/IERC7579Account.sol";

library ERC7579Execution {
    ModeCode constant SINGLE = ModeCode.wrap(bytes32(0));

    function execute(
        address account,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bytes memory result)
    {
        return IERC7579Account(account).executeFromExecutor(
            SINGLE, ExecutionLib.encodeSingle(to, value, data)
        )[0];
    }
}
