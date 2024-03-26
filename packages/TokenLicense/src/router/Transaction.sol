// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import "../DataTypes.sol";
import "./ModuleRecords.sol";
import "../lib/LicenseHash.sol";
import "../lib/ClaimLib.sol";

abstract contract Transaction is ModuleRecords {
    using ClaimLib for ISignatureTransfer.TokenPermissions[];
    using LicenseHash for *;

    function claimTxFee(TransactionClaim memory claim) external {
        IFeeMachine shareholder = $moduleShareholders[msg.sender];
        (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        ) = shareholder.getPermitTx(claim);
        uint256 feeAmount = permissions.totalAmount();

        // TODO: enforce check fee caps
        claim.amount = feeAmount;

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permissions,
            nonce: _iterModuleNonce({ module: msg.sender }),
            deadline: block.timestamp
        });

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: transfers,
            owner: claim.smartAccount,
            witness: _hashTypedData(claim.hash()),
            witnessTypeString: TXCLAIM_STRING,
            signature: abi.encodePacked(SIGNER_TX_SELF, abi.encode(permit, claim))
        });
    }

    function claimTxFee(TransactionClaim memory claim, address referral) external {
        IFeeMachine shareholder = $moduleShareholders[msg.sender];
        (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        ) = shareholder.getPermitTx(claim, referral);
        uint256 feeAmount = permissions.totalAmount();

        // TODO: enforce check fee caps
        claim.amount = feeAmount;

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permissions,
            nonce: _iterModuleNonce({ module: msg.sender }),
            deadline: block.timestamp
        });

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: transfers,
            owner: claim.smartAccount,
            witness: _hashTypedData(claim.hash()),
            witnessTypeString: TXCLAIM_STRING,
            signature: abi.encodePacked(SIGNER_TX_SELF, abi.encode(permit, claim))
        });
    }

    function claimTxFee(address sponsor, TransactionClaim memory claim) external {
        IFeeMachine shareholder = $moduleShareholders[msg.sender];
        (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        ) = shareholder.getPermitTx(claim);
        uint256 feeAmount = permissions.totalAmount();

        // TODO: enforce check fee caps

        claim.amount = feeAmount;

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permissions,
            nonce: _iterModuleNonce({ module: msg.sender }),
            deadline: block.timestamp
        });

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: transfers,
            owner: sponsor,
            witness: _hashTypedData(claim.hash(sponsor)),
            witnessTypeString: TXCLAIM_SPONSOR_STRING,
            signature: abi.encodePacked(SIGNER_TX_SPONSOR, abi.encode(permit, claim))
        });
    }

    function claimTxFee(
        address sponsor,
        TransactionClaim memory claim,
        address referral
    )
        external
    {
        IFeeMachine shareholder = $moduleShareholders[msg.sender];
        (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        ) = shareholder.getPermitTx(claim, referral);
        uint256 feeAmount = permissions.totalAmount();

        // TODO: enforce check fee caps

        claim.amount = feeAmount;

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permissions,
            nonce: _iterModuleNonce({ module: msg.sender }),
            deadline: block.timestamp
        });

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: transfers,
            owner: sponsor,
            witness: _hashTypedData(claim.hash(sponsor)),
            witnessTypeString: TXCLAIM_SPONSOR_STRING,
            signature: abi.encodePacked(SIGNER_TX_SPONSOR, abi.encode(permit, claim))
        });
    }
}
