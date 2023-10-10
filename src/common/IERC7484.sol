// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC7484Registry {
    function check(address executor, address attester) external view returns (uint256 listedAt);
}
