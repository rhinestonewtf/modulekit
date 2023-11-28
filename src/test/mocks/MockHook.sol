// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import { IHook, ExecutorTransaction } from "../../modulekit/interfaces/IHook.sol";

contract MockHook is IHook {
    function preCheck(
        address account,
        ExecutorTransaction calldata transaction,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        returns (bytes memory preCheckData)
    { }

    function preCheckRootAccess(
        address account,
        ExecutorTransaction calldata rootAccess,
        uint256 executionType,
        bytes calldata executionMeta
    )
        external
        returns (bytes memory preCheckData)
    { }

    function postCheck(address account, bool success, bytes calldata preCheckData) external { }
}
