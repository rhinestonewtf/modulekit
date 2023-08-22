// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRegistry {
    function check(address executor, address trustedEntity) external view returns (uint48 listedAt, uint48 revokedAt);
}
