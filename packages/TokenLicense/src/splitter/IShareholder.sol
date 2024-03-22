// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";

interface IShareholder {
    function getPermitTransfers(TransactionClaim calldata claim)
        external
        returns (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        );

    function getPermitTransfers(
        TransactionClaim calldata claim,
        address referal
    )
        external
        returns (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        );

    function getPermitTransfers(SubscriptionClaim calldata claim)
        external
        returns (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        );

    function getPermitTransfers(
        SubscriptionClaim calldata claim,
        address referal
    )
        external
        returns (
            ISignatureTransfer.TokenPermissions[] memory permissions,
            ISignatureTransfer.SignatureTransferDetails[] memory transfers
        );
}
