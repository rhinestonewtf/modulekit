// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ClaimType, Currency } from "../DataTypes.sol";
import { IFeeMachine } from "./IFeeMachine.sol";

interface IProtocolController {
    function isSubscriptionCurrency(
        address module,
        Currency currency
    )
        external
        view
        returns (bool ok);
    function protocolFeeForModule(
        address account,
        address module,
        IFeeMachine feeMachine,
        uint256 feeMachineAmount,
        Currency currency,
        ClaimType claimType
    )
        external
        view
        returns (uint256 bps, address beneficiary);
}
