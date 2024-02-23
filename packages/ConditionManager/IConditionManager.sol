// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IConditionManager {
    function checkConditions(
        address smartAccount,
        bytes calldata conditionData
    )
        external
        view
        returns (bool);

    function checkConditions(
        address smartAccount,
        bytes calldata conditionData,
        bytes calldata subParamData
    )
        external
        view
        returns (bool);
}
