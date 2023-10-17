// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICondition } from "../IExecutor.sol";

contract GasPriceCondition is ICondition {
    struct ConditionParams {
        uint256 maxGasPrice;
    }

    function checkCondition(
        address,
        address,
        bytes calldata _params,
        bytes calldata _subParams
    )
        external
        view
        returns (bool)
    {
        ConditionParams memory params = abi.decode(_params, (ConditionParams));
        if (params.maxGasPrice >= tx.gasprice) return true;
    }
}
