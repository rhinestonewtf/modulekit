// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/DataTypes.sol";
import "src/interfaces/IProtocolController.sol";

contract MockProtocolController is IProtocolController {
    function isSubscriptionCurrency(
        address module,
        Currency currency
    )
        external
        view
        virtual
        override
        returns (bool ok)
    {
        return true;
    }

    function protocolFeeForModule(
        address module,
        IFeeMachine feeMachine,
        ClaimType claimType
    )
        external
        view
        virtual
        override
        returns (uint256 protocolFee, address beneficiary)
    {
        protocolFee = 100;
        beneficiary = address(this);
    }
}
