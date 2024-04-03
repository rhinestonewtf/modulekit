// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import "../DataTypes.sol";
import "./ModuleRecords.sol";
import "./Subscription.sol";
import "../lib/LicenseHash.sol";
import "../lib/LicenseManagerLib.sol";

import "forge-std/console2.sol";
import "forge-std/interfaces/IERC20.sol";

abstract contract ProcessClaim is ModuleRecords, Subscription {
    using ClaimLib for ISignatureTransfer.TokenPermissions[];
    using LicenseHash for *;
    using TokenPermissionsLib for ISignatureTransfer.SignatureTransferDetails[];

    event TranactionClaim(address account, address module, uint256 amount);
    event SubscriptionClaim(address account, address module, uint256 amount);
    event UsageClaim(address account, address module, uint256 amount);

    function permitClaim(address payer, address referral, Claim memory claim) external {
        IFeeMachine shareholder = $moduleShareholders[claim.module];
        ISignatureTransfer.SignatureTransferDetails[] memory transfers =
            shareholder.getSplit(claim, referral);

        if (claim.claimType == ClaimType.Transaction) {
            require(claim.module == msg.sender, "Invalid module");
            _settleClaim(payer, claim, transfers);
            emit TranactionClaim(claim.smartAccount, msg.sender, claim.usdAmount);
        } else if (claim.claimType == ClaimType.Subscription) {
            uint48 newValidUntil = _validUntil(claim.smartAccount, claim.module, claim.usdAmount);
            $activeLicenses[claim.module][claim.smartAccount].validUntil = newValidUntil;
            _settleClaim(payer, claim, transfers);
            emit SubscriptionClaim(claim.smartAccount, claim.module, claim.usdAmount);
        } else if (claim.claimType == ClaimType.SingleCharge) {
            require(claim.module == msg.sender, "Invalid module");
            _settleClaim(payer, claim, transfers);
            emit UsageClaim(claim.smartAccount, msg.sender, claim.usdAmount);
        }
    }

    function _settleClaim(
        address payer,
        Claim memory claim,
        ISignatureTransfer.SignatureTransferDetails[] memory transfers
    )
        internal
        returns (uint256 totalAmount)
    {
        ISignatureTransfer.TokenPermissions[] memory permissions;
        // no swap required. just transfer the token from the smart account to the beneficiaries
        if (address(claim.payToken) == FEE_TOKEN) {
            (permissions, totalAmount) = transfers.makeTokenPermissions(FEE_TOKEN);

            // claim.usdAmount = totalAmount; // TODO

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
                witnessTypeString: CLAIM_STRING,
                signature: abi.encodePacked(SIGNER, abi.encode(permit, claim))
            });
        }
        // swap required
        else {
            exactOutputSingle(
                SwapParams({
                    tokenIn: address(claim.payToken),
                    tokenOut: address(FEE_TOKEN),
                    fee: 3000,
                    amountOut: claim.usdAmount, // TODO this means the claim must have the USD
                        // amount
                    sqrtPriceLimitX96: 0, // TODO
                    payer: payer,
                    recipient: address(this)
                }),
                claim
            );
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
        uint256 amount,
        Claim memory claim
    )
        internal
        override
    {
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

        PERMIT2.permitWitnessTransferFrom({
            permit: permit,
            transferDetails: transfer,
            owner: payer,
            witness: _hashTypedData(claim.hash()),
            witnessTypeString: CLAIM_STRING,
            signature: abi.encodePacked(SIGNER, abi.encode(permit, claim))
        });
    }
}
