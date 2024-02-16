// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ICondition {
    function checkCondition(
        address account,
        address module,
        bytes calldata boundries,
        bytes calldata subParams
    )
        external
        view
        returns (bool);
}
