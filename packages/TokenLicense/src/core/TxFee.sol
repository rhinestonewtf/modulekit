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
    // using PermitHash for ISignatureTransfer.PermitTransformFrom;

    struct LicenseManagerTxFee {
        address module;
        uint256 amount;
    }

    string constant TX_FEE_WITNESS = "LicenseManagerTxFee(address module, uint256 amount)";
    bytes32 constant TX_FEE_HASH = keccak256(abi.encodePacked(TX_FEE_WITNESS));

    function approvalTxFee(address smartAccount, uint256 totalAmount) external {
        ModuleMoneyConf storage $moduleMonetization = _moduleMoneyConfs[msg.sender];
        address splitter = $moduleMonetization.splitter;
        require(splitter != address(0), "invalid module");
        uint256 amount = _calculateTxFee(totalAmount, $moduleMonetization);
        address(TOKEN).safeTransferFrom(smartAccount, splitter, amount);
    }

    function signedTxFee(
        address smartAccount,
        uint256 totalAmount,
        bytes calldata signature
    )
        external
    { }

    function permitTxFee(
        address smartAccount,
        uint256 totalAmount,
        bytes calldata signature
    )
        external
    {
        address splitter = _moduleMoneyConfs[msg.sender].splitter;
        uint256 nonce = 123; // todo iter
        bytes32 witness = _hashTypedData(
            keccak256(abi.encode(LicenseManagerTxFee({ module: msg.sender, amount: totalAmount })))
        );

        ISignatureTransfer.SignatureTransferDetails memory signatureTransfer = ISignatureTransfer
            .SignatureTransferDetails({
            to: splitter, // recipient address
            requestedAmount: totalAmount //total amount sent to receiver
         });

        PERMIT2.permitWitnessTransferFrom({
            permit: ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({ token: TOKEN, amount: totalAmount }),
                nonce: nonce,
                deadline: block.timestamp + 1000
            }),
            transferDetails: signatureTransfer,
            owner: smartAccount,
            witness: witness,
            witnessTypeString: TX_FEE_WITNESS,
            signature: abi.encodePacked(SIGNER_MODULE, abi.encode(msg.sender, totalAmount))
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
}
