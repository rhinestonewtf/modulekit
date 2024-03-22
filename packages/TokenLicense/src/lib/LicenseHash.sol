// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";

library LicenseHash {
    function hash(TransactionClaim memory claim) internal pure returns (bytes32) {
        return keccak256(abi.encode(TXCLAIM_HASH, keccak256(abi.encode(claim))));
    }

    function hash(SubscriptionClaim memory claim) internal pure returns (bytes32) {
        return keccak256(abi.encode(SUBCLAIM_HASH, keccak256(abi.encode(claim))));
    }
}
