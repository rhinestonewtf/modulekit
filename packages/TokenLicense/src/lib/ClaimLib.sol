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
