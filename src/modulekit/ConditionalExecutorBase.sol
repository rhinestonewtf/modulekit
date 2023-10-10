// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./ExecutorBase.sol";
import "../core/ComposableCondition.sol";

abstract contract ConditionalExecutor is ExecutorBase {
    ComposableConditionManager private _conditionManager;

    constructor(ComposableConditionManager conditionManager) {
        _conditionManager = conditionManager;
    }

    function _check(address account, ConditionConfig[] calldata conditions) internal view {
        _conditionManager.check(account, conditions);
    }
}
