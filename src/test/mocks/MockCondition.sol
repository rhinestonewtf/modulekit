// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ICondition } from "../..//modulekit/IExecutor.sol";

contract MockCondition is ICondition {
    function check(
        address account,
        address executor,
        bytes calldata boundries
    )
        external
        view
        override
        returns (bool)
    {
        return true;
    }
}
