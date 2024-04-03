// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";

library ClaimLib {
    function totalAmount(ISignatureTransfer.TokenPermissions[] memory permissions)
        internal
        pure
        returns (uint256)
    {
        uint256 total;
        for (uint256 i; i < permissions.length; i++) {
            total += permissions[i].amount;
        }
        return total;
    }
}

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
