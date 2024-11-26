// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

struct Execution {
    address target;
    uint256 value;
    bytes callData;
}
