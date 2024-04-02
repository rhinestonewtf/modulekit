// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import "../DataTypes.sol";
import "./ModuleRecords.sol";
import "../lib/LicenseHash.sol";
import "../lib/ClaimLib.sol";

import "forge-std/console2.sol";
import "forge-std/interfaces/IERC20.sol";

library TokenPermissionsLib {
    function makeTokenPermissions(
        ISignatureTransfer.SignatureTransferDetails[] memory transfers,
        address token
    )
        internal
        pure
        returns (ISignatureTransfer.TokenPermissions[] memory permissions, uint256 totalAmount)
    {
        uint256 length = transfers.length;
        permissions = new ISignatureTransfer.TokenPermissions[](length);
        for (uint256 i; i < length; i++) {
            uint256 amount = transfers[i].requestedAmount;
            totalAmount += amount;
            permissions[i] = ISignatureTransfer.TokenPermissions({ token: token, amount: amount });
        }
    }
}

abstract contract Transaction is ModuleRecords {
    using ClaimLib for ISignatureTransfer.TokenPermissions[];
    using LicenseHash for *;
    using TokenPermissionsLib for ISignatureTransfer.SignatureTransferDetails[];

    function claimTxFee(TransactionClaim memory claim) external {
        IFeeMachine shareholder = $moduleShareholders[msg.sender];
        // get shareholders for module
        ISignatureTransfer.SignatureTransferDetails[] memory transfers =
            shareholder.getPermitTx(claim);
        uint256 totalAmount = _handleClaim(claim.smartAccount, claim, transfers);
    }

    function claimTxFee(TransactionClaim memory claim, address referral) external {
        IFeeMachine shareholder = $moduleShareholders[msg.sender];
        ISignatureTransfer.SignatureTransferDetails[] memory transfers =
            shareholder.getPermitTx(claim, referral);
        uint256 totalAmount = _handleClaim(claim.smartAccount, claim, transfers);
    }

    function claimTxFee(address sponsor, TransactionClaim memory claim) external {
        IFeeMachine shareholder = $moduleShareholders[msg.sender];
        ISignatureTransfer.SignatureTransferDetails[] memory transfers =
            shareholder.getPermitTx(claim);
        uint256 totalAmount = _handleClaim(sponsor, claim, transfers);
    }

    function claimTxFee(
        address sponsor,
        TransactionClaim memory claim,
        address referral
    )
        external
    {
        IFeeMachine shareholder = $moduleShareholders[msg.sender];
        ISignatureTransfer.SignatureTransferDetails[] memory transfers =
            shareholder.getPermitTx(claim, referral);
        uint256 totalAmount = _handleClaim(sponsor, claim, transfers);
    }

    function _handleClaim(
        address payer,
        TransactionClaim memory claim,
        ISignatureTransfer.SignatureTransferDetails[] memory transfers
    )
        internal
        returns (uint256 totalAmount)
    {
        ISignatureTransfer.TokenPermissions[] memory permissions;
        // no swap required. just transfer the token from the smart account to the beneficiaries
        if (address(claim.token) == FEE_TOKEN) {
            (permissions, totalAmount) = transfers.makeTokenPermissions(FEE_TOKEN);

            claim.amount = totalAmount;

            ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
                .PermitBatchTransferFrom({
                permitted: permissions,
                nonce: _iterModuleNonce({ module: msg.sender }),
                deadline: block.timestamp
            });

            PERMIT2.permitWitnessTransferFrom({
                permit: permit,
                transferDetails: transfers,
                owner: payer,
                witness: _hashTypedData(claim.hash()),
                witnessTypeString: TXCLAIM_STRING,
                signature: abi.encodePacked(SIGNER_TX_SELF, abi.encode(permit, claim))
            });
        }
        // swap required
        else {
            console2.log("totalAmount", claim.amount);
            console2.log("blaance", IERC20(claim.token).balanceOf(address(this)));
            exactOutputSingle(
                SwapParams({
                    tokenIn: address(claim.token),
                    tokenOut: address(FEE_TOKEN),
                    fee: 3000,
                    amountOut: claim.amount, // TODO this means the claim must have the USD amount
                    sqrtPriceLimitX96: 0,
                    payer: payer,
                    recipient: address(this)
                })
            );
            console2.log("blaance", IERC20(claim.token).balanceOf(address(this)));
            // execution flow will call uniswapV3Callback(). which will send the token from the
            // smart account to the LP
            // LP will send the fee token to address(this)
            uint256 length = transfers.length;
            // Send token to beneficiaries

            for (uint256 i; i < length; i++) {
                IERC20(FEE_TOKEN).transfer(transfers[i].to, transfers[i].requestedAmount);
            }
        }
    }

    function _permitPay(
        address token,
        address payer,
        address receiver,
        uint256 amount
    )
        internal
        override
    {
        console2.log("permitPay", token, amount);
        // use permit2 to transfer the token from the smart accdount to license router:
        ISignatureTransfer.TokenPermissions[] memory permission =
            new ISignatureTransfer.TokenPermissions[](1);
        permission[0] = ISignatureTransfer.TokenPermissions({ token: token, amount: amount });
        ISignatureTransfer.SignatureTransferDetails[] memory transfer =
            new ISignatureTransfer.SignatureTransferDetails[](1);
        transfer[0] =
            ISignatureTransfer.SignatureTransferDetails({ to: receiver, requestedAmount: amount });

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer
            .PermitBatchTransferFrom({
            permitted: permission,
            nonce: _iterModuleNonce({ module: msg.sender }),
            deadline: block.timestamp
        });

        TransactionClaim memory claim = TransactionClaim({
            module: msg.sender,
            smartAccount: receiver,
            token: IERC20(token),
            amount: amount,
            data: ""
        });

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: transfer,
            owner: payer,
            witness: _hashTypedData(claim.hash()),
            witnessTypeString: TXCLAIM_STRING,
            signature: abi.encodePacked(SIGNER_TX_SELF, abi.encode(permit, claim))
        });
    }
}
