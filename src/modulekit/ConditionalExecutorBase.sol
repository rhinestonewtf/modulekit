// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./ExecutorBase.sol";
import "../core/ComposableCondition.sol";

/**
 * @title ConditionalExecutor
 * This contract extends the functionality of the ExecutorBase, providing
 * capabilities to conditionally execute transactions based on the checks
 * performed by the ComposableConditionManager.
 *
 * @dev use this Executor as Base if you want to build an Executor with user supplied conditions
 */
abstract contract ConditionalExecutor is ExecutorBase {
    // Condition manager signleton instance that helps in evaluating conditions
    ComposableConditionManager private immutable _conditionManager;

    /**
     * @dev Constructs the contract and initializes the condition manager.
     * @param conditionManager Address of the ComposableConditionManager contract.
     */
    constructor(ComposableConditionManager conditionManager) {
        _conditionManager = conditionManager;
    }

    /**
     * @dev Modifier to ensure the conditions are met before executing a function.
     * @param account The address against which the conditions are checked.
     * @param conditions Array of conditions to be checked.
     */
    modifier onlyIfConditionsMet(address account, ConditionConfig[] calldata conditions) virtual {
        _checkConditions(account, conditions);
        _;
    }

    /**
     * @notice Checks if the provided conditions for an account are satisfied.
     * @param account The address against which the conditions are checked.
     * @param conditions Array of conditions to be checked.
     */
    function _checkConditions(
        address account,
        ConditionConfig[] calldata conditions
    )
        internal
        view
    {
        _conditionManager.checkCondition(account, conditions);
    }
}
