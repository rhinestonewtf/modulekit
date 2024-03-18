// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { Subscription } from "./Subscription.sol";
import { ILicenseManager } from "../interfaces/ILicenseManager.sol";
import "../DataTypes.sol";
import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";
import "forge-std/console2.sol";

abstract contract TxFee is Subscription {
    using SafeTransferLib for address;

    function claimTxFee(address smartAccount, uint256 totalAmount) external {
        ModuleMoneyConf storage $moduleMoneyConf = _moduleMoneyConfs[msg.sender];
        address splitter = $moduleMoneyConf.splitter;
        totalAmount = _calculateTxFee(totalAmount, $moduleMoneyConf);
        if (totalAmount == 0) return;
        if (splitter == address(0)) revert UnauthorizedModule();

        bytes memory message =
            abi.encode(LicenseManagerTxFee({ module: msg.sender, amount: totalAmount }));
        bytes32 witness = _hashTypedData(keccak256(message));

        ISignatureTransfer.SignatureTransferDetails memory signatureTransfer = ISignatureTransfer
            .SignatureTransferDetails({
            to: splitter, // recipient address
            requestedAmount: totalAmount //total amount sent to receiver
         });

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({ token: TOKEN, amount: totalAmount }),
            nonce: _iterNonce({ module: msg.sender }),
            deadline: block.timestamp
        });

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: signatureTransfer,
            owner: smartAccount,
            witness: witness,
            witnessTypeString: TX_FEE_WITNESS,
            signature: abi.encodePacked(txFeeSessionKey, abi.encode(permit, message))
        });
    }

    function _calculateTxFee(
        uint256 totalAmount,
        ModuleMoneyConf storage $moduleMonetization
    )
        internal
        view
        returns (uint256)
    {
        return (totalAmount * $moduleMonetization.txPercentage) / 100;
    }

    function claimSubscriptionRenewal(address smartAccount) external {
        // how many seconds does the amount cover?
        ModuleMoneyConf storage $moduleMoney = _moduleMoneyConfs[msg.sender];
        address splitter = $moduleMoney.splitter;
        if (splitter == address(0)) revert UnauthorizedModule();
        License storage $license = _accountLicenses[msg.sender][smartAccount];

        (uint48 newValidUntil, uint256 totalAmount) =
            _calculateSubscriptionFee($moduleMoney, $license);
        $license.validUntil = newValidUntil;

        bytes memory message =
            abi.encode(LicenseManagerSubscription({ module: msg.sender, amount: totalAmount }));
        bytes32 witness = _hashTypedData(keccak256(message));

        ISignatureTransfer.SignatureTransferDetails memory signatureTransfer = ISignatureTransfer
            .SignatureTransferDetails({
            to: splitter,
            requestedAmount: totalAmount //total amount sent to receiver
         });

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({ token: TOKEN, amount: totalAmount }),
            nonce: _iterNonce({ module: msg.sender }),
            deadline: block.timestamp
        });

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: signatureTransfer,
            owner: smartAccount,
            witness: witness,
            witnessTypeString: SUBSCRIPTION_WITNESS,
            signature: abi.encodePacked(subscriptionSessionKey, abi.encode(permit, message))
        });
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
