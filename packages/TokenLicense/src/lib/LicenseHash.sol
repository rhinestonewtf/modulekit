// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";

library LicenseHash {
    function hash(LicenseManagerSubscription memory subscription) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(SUBSCRIPTION_WITNESS_TYPEHASH, keccak256(abi.encode(subscription)))
        );
    }

    function hash(LicenseManagerTxFee memory txFee) internal pure returns (bytes32) {
        return keccak256(abi.encode(TX_FEE_WITNESS_TYPEHASH, keccak256(abi.encode(txFee))));
    }
}
