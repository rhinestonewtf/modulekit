// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

interface IEIP712 {
    function domainSeparator() external view returns (bytes32);
}
