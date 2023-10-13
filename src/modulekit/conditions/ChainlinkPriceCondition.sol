// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICondition } from "../IExecutor.sol";
import "./helpers/ChainlinkTokenPrice.sol";

contract ChainlinkPriceCondition is ICondition, ChainlinkTokenPrice {
    enum PriceState {
        OVER,
        UNDER
    }

    struct Params {
        address tokenAddr;
        uint256 price;
        PriceState state;
    }

    function checkCondition(
        address,
        address,
        bytes calldata conditionData,
        bytes calldata subParams
    )
        external
        view
        override
        returns (bool)
    {
        Params memory params = abi.decode(conditionData, (Params));

        uint256 currentTokenPriceInUSD = getPriceInUSD(params.tokenAddr);

        if (params.state == PriceState.OVER) {
            if (currentTokenPriceInUSD > params.price) {
                return true;
            }
        } else if (params.state == PriceState.UNDER) {
            if (currentTokenPriceInUSD < params.price) {
                return true;
            }
        }
        return false;
    }
}
