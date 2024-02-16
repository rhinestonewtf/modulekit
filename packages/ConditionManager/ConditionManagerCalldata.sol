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

function decodeCondition(bytes calldata _conditions)
    pure
    returns (ConditionConfig[] calldata conditions)
{
    // solhint-disable-next-line no-inline-assembly
    assembly ("memory-safe") {
        let offset := add(_conditions.offset, 0)
        let baseOffset := offset

        let dataPointer := add(baseOffset, calldataload(offset))
        conditions.offset := add(dataPointer, 32)
        conditions.length := calldataload(dataPointer)
    }
}

contract ConditionManager is IConditionManager {
    mapping(address account => mapping(address module => bytes32 digest)) internal _conditions;

    function digest(ConditionConfig[] calldata conditions) public pure returns (bytes32) {
        return keccak256(abi.encode(conditions));
    }

    function checkConditions(
        address smartAccount,
        bytes calldata conditionData
    )
        external
        view
        override
        returns (bool)
    {
        ConditionConfig[] calldata conditions = decodeCondition(conditionData);
        bytes32 _digest = digest(conditions);
        if (_conditions[smartAccount][msg.sender] != _digest) {
            revert("Invalid Conditions");
        }
        for (uint256 i = 0; i < conditions.length; i++) {
            bytes calldata _conditionData = conditions[i].conditionData;
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
