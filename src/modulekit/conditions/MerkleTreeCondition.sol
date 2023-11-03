// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICondition } from "../interfaces/IExecutor.sol";
import { ChainlinkTokenPrice } from "./helpers/ChainlinkTokenPrice.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";

contract MerkleTreeCondition is ICondition, ChainlinkTokenPrice {
    struct Params {
        bytes32 root;
    }

    struct ExecutorParams {
        bytes32[] proof;
        bytes32 leaf;
    }

    event ScheduleUpdated(address account, uint256 lastExecuted);

    function checkCondition(
        address account,
        address executor,
        bytes calldata conditionData,
        bytes calldata subParams
    )
        external
        view
        override
        returns (bool)
    {
        Params memory params = abi.decode(conditionData, (Params));
        ExecutorParams memory executorParams = abi.decode(subParams, (ExecutorParams));

        return MerkleProofLib.verify(executorParams.proof, params.root, executorParams.leaf);
    }
}
