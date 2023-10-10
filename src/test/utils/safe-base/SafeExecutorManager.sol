// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ExecutorManager } from "../../../core/executionManager/ExecutorManager.sol";
import "../../../common/ISafe.sol";

import "../../../common/IERC7484.sol";

contract SafeExecutorManager is ExecutorManager {
    constructor(IERC7484Registry registry) ExecutorManager(registry) { }

    function _execTransationOnSmartAccount(
        address safe,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        override
        returns (bool success, bytes memory)
    {
        success = ISafe(safe).execTransactionFromModule(to, value, data, 0);
    }
}
