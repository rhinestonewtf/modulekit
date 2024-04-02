// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import "./Transaction.sol";
import "../lib/ClaimLib.sol";
import "../lib/LicenseHash.sol";

import "forge-std/console2.sol";

abstract contract Subscription is Transaction {
    using TokenPermissionsLib for ISignatureTransfer.SignatureTransferDetails[];
    using ClaimLib for ISignatureTransfer.TokenPermissions[];
    using LicenseHash for *;

    error SubscriptionAmountTooLow(uint256 amount, uint256 minAmount);

    event NewSubscription(address account, address module, uint48 newValidUntil);

    mapping(address module => mapping(address account => LicenseRecord)) internal $activeLicenses;
    mapping(address module => SubscriptionConfig conf) internal $moduleSubPricing;

    function subscriptionRenewal(address module, SubscriptionClaim memory claim) external {
        IFeeMachine shareholder = $moduleShareholders[module];
        $activeLicenses[module][claim.smartAccount].validUntil =
            _calculateSubscriptionFee(claim.smartAccount, module, claim.amount);

        ISignatureTransfer.SignatureTransferDetails[] memory transfers =
            shareholder.getPermitSub(claim);

        uint256 totalAmount = _handleClaim(claim.smartAccount, claim, transfers);

        emit NewSubscription(
            claim.smartAccount, module, $activeLicenses[module][claim.smartAccount].validUntil
        );
    }

    function setSubscriptionConfig(
        address module,
        uint128 pricePerSecond,
        uint128 minSubTime
    )
        external
    {
        $moduleSubPricing[module] =
            SubscriptionConfig({ pricePerSecond: pricePerSecond, minSubTime: minSubTime });
    }

    function _calculateSubscriptionFee(
        address smartAccount,
        address module,
        uint256 amount
    )
        internal
        view
        returns (uint48 newValidUntil)
    {
        SubscriptionConfig memory subscriptionRecord = $moduleSubPricing[module];
        uint256 minAmount = subscriptionRecord.minSubTime * subscriptionRecord.pricePerSecond;
        if (amount < minAmount) revert SubscriptionAmountTooLow(amount, minAmount);
        uint256 currentValidUntil = checkLicenseUntil(smartAccount, module);

        newValidUntil = (currentValidUntil == 0)
            ? uint48(block.timestamp + subscriptionRecord.minSubTime) // license is not valid, so
                // start from now
            : uint48(currentValidUntil + subscriptionRecord.minSubTime); // license is valid, so extend

        if (newValidUntil < block.timestamp) {
            revert SubscriptionTooShort();
        }
    }

    function checkLicense(address account, address module) external view returns (bool) {
        return $activeLicenses[module][account].validUntil > block.timestamp;
    }

    function checkLicenseUntil(address account, address module) public view returns (uint48) {
        return $activeLicenses[module][account].validUntil;
    }

    function _handleClaim(
        address payer,
        SubscriptionClaim memory claim,
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
}
