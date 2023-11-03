// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICondition } from "../interfaces/IExecutor.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";

contract MerkleTreeCondition is ICondition {
    struct Params {
        bytes32 root;
    }

    struct MerkleParams {
        bytes32[] proof;
        bytes32 leaf;
    }

    event ScheduleUpdated(address account, uint256 lastExecuted);

    function checkCondition(
        address,
        address,
        bytes calldata conditionData,
        bytes calldata subParams
    )
        external
        pure
        override
        returns (bool)
    {
        Params memory params = abi.decode(conditionData, (Params));
        MerkleParams memory executorParams = abi.decode(subParams, (MerkleParams));

        return MerkleProofLib.verify(executorParams.proof, params.root, executorParams.leaf);
    }
}
