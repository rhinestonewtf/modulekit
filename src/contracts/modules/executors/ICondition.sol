// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICondition {
    function check(
        address account,
        address executor,
        bytes calldata boundries
    )
        external
        view
        returns (bool);
}
