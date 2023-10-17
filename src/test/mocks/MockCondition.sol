// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ICondition } from "../..//modulekit/IExecutor.sol";

contract MockCondition is ICondition {
    function checkCondition(
        address account,
        address executor,
        bytes calldata conditionData,
        bytes calldata subData
    )
        external
        view
        returns (bool)
    {
        return true;
    }
}
