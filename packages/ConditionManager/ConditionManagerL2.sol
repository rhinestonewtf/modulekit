// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IConditionManager } from "./IConditionManager.sol";
import { ICondition } from "./ICondition.sol";

/**
 * @dev Represents a single condition configuration. It captures the boundary data and associated
 * condition logic.
 * conditionData - A generic data field that may contain additional context for the condition.
 * condition - An instance of an `ICondition` implementation that encapsulates the condition logic.
 */
struct ConditionConfig {
    ICondition condition;
    bytes conditionData;
}

contract ConditionManager is IConditionManager {
    mapping(address account => mapping(address module => ConditionConfig[] conditions)) internal
        _conditions;

    function digest(ConditionConfig[] calldata conditions) public pure returns (bytes32) {
        return keccak256(abi.encode(conditions));
    }

    function checkConditions(
        address smartAccount,
        bytes calldata
    )
        external
        view
        override
        returns (bool)
    {
        ConditionConfig[] storage conditions = _conditions[smartAccount][msg.sender];
        uint256 length = conditions.length;
        for (uint256 i; i < length; i++) {
            bytes storage _conditionData = conditions[i].conditionData;
            if (
                !conditions[i].condition.checkCondition(smartAccount, msg.sender, _conditionData, "")
            ) {
                return false;
            }
        }

        return true;
    }

    function checkConditions(
        address smartAccount,
        bytes calldata conditionData,
        bytes calldata subParamData
    )
        external
        view
        override
        returns (bool)
    { }
}
