// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";

library LicenseHash {
    function hash(Claim memory claim) internal pure returns (bytes32) {
        return keccak256(abi.encode(CLAIM_HASH, keccak256(abi.encode(claim))));
    }
}
