// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LicensedModuleBase } from "./Base.sol";
import "../DataTypes.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

abstract contract TransactionFeeExecutorBase is LicensedModuleBase {
    function _handleTransactionFee(
        address smartAccount,
        IERC20 token,
        uint256 totalAmount
    )
        internal
        returns (uint256 remainingAmount)
    {
        remainingAmount = totalAmount
            - LICENSE_MANAGER.settleTransaction(
                ClaimTransaction({
                    account: smartAccount,
                    currency: Currency.wrap(address(token)),
                    amount: totalAmount,
                    feeMachineData: "",
                    referral: address(0)
                })
            );
    }
}
