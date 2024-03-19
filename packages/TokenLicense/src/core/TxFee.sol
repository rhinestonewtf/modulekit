// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { Shareholder } from "./Shareholder.sol";
import { ILicenseManager } from "../interfaces/ILicenseManager.sol";
import { ModuleMonetization } from "./ModuleMonetization.sol";
import { LicenseCheck } from "./LicenseCheck.sol";
import { LicenseHash } from "../lib/LicenseHash.sol";
import "../DataTypes.sol";
import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import "forge-std/console2.sol";

abstract contract TxFee is Shareholder, ModuleMonetization, LicenseCheck {
    using SafeTransferLib for address;
    using LicenseHash for LicenseManagerTxFee;
    using LicenseHash for LicenseManagerSubscription;

    function claimTxFee(
        address smartAccount,
        address sponsor,
        IERC20 token,
        uint256 totalAmount
    )
        external
    {
        (
            uint256 feeAmount,
            bps txPercentage,
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails
        ) = getTokenPermissions({ module: msg.sender, token: token, totalAmount: totalAmount });

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permissions,
            nonce: _iterNonce({ module: msg.sender }),
            deadline: block.timestamp
        });

        LicenseManagerTxFee memory message = LicenseManagerTxFee({
            amount: feeAmount,
            module: msg.sender,
            sponsor: sponsor,
            txPercentage: txPercentage
        });

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: transferDetails,
            owner: sponsor,
            witness: _hashTypedData(message.hash()),
            witnessTypeString: TX_FEE_WITNESS,
            signature: abi.encodePacked(txFeeSessionKey, abi.encode(permit, message))
        });

        emit TransactionFee(msg.sender, smartAccount, sponsor, token, feeAmount);
    }

    function _calculateTxFee(
        uint256 totalAmount,
        ModuleMoneyConf storage $moduleMonetization
    )
        internal
        view
        returns (uint256 _totalAmount, uint32 txPercentage)
    {
        txPercentage = $moduleMonetization.txPercentage;
        _totalAmount = (totalAmount * txPercentage) / 100;
    }

    function claimSubscriptionRenewal(address smartAccount, address sponsor) external {
        // how many seconds does the amount cover?
        ModuleMoneyConf storage $moduleMoney = _moduleMoneyConfs[msg.sender];
        License storage $license = _accountLicenses[msg.sender][smartAccount];

        console2.log("foo");

        (uint48 newValidUntil, uint256 totalAmount) =
            _calculateSubscriptionFee($moduleMoney, $license);
        $license.validUntil = newValidUntil;
        totalAmount = 1e18;

        (
            uint256 feeAmount,
            ,
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails
        ) = getTokenPermissions({
            module: msg.sender,
            token: $moduleMoney.token,
            totalAmount: totalAmount
        });

        console2.log("foo");

        LicenseManagerSubscription memory message =
            LicenseManagerSubscription({ module: msg.sender, sponsor: sponsor, amount: feeAmount });

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permissions,
            nonce: _iterNonce({ module: msg.sender }),
            deadline: block.timestamp
        });

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: transferDetails,
            owner: smartAccount,
            witness: _hashTypedData(message.hash()),
            witnessTypeString: SUBSCRIPTION_WITNESS,
            signature: abi.encodePacked(subscriptionSessionKey, abi.encode(permit, message))
        });

        emit SubscriptionFee(smartAccount, msg.sender, totalAmount, newValidUntil);
    }

    function _calculateSubscriptionFee(
        ModuleMoneyConf storage $moduleMoney,
        License storage $license
    )
        internal
        view
        returns (uint48 newValidUntil, uint256 totalAmount)
    {
        uint256 pricePerSecond = $moduleMoney.pricePerSecond;
        uint256 minSubSeconds = $moduleMoney.minSubSeconds;
        totalAmount = minSubSeconds * pricePerSecond;
        uint256 validUntil = $license.validUntil;

        newValidUntil = (validUntil == 0)
            ? uint48(block.timestamp + minSubSeconds) // license is not valid, so start from now
            : uint48(validUntil + minSubSeconds); // license is valid, so extend it

        // check if newValidUntil is greater that minimum subscription perion
        if (newValidUntil < block.timestamp + _moduleMoneyConfs[msg.sender].minSubSeconds) {
            revert SubscriptionTooShort();
        }
    }
}
