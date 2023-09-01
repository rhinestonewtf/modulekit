// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../contracts/modules/executors/IExecutorBase.sol";

struct DebugData {
    address account;
    ExecutorTransaction transaction;
}

contract DebugExecutorManager is IExecutorManager {
    DebugData public storeData;

    ExecutorTransaction public transaction;

    function executeTransaction(
        address account,
        ExecutorTransaction calldata transaction
    )
        external
        override
        returns (bytes[] memory data)
    {
        storeData.account = account;
        storeData.transaction = transaction;
    }
}
