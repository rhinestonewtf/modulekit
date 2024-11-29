// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

interface IKernelFactory {
    function createAccount(bytes calldata data, bytes32 salt) external payable returns (address);
    function getAddress(bytes calldata data, bytes32 salt) external returns (address);
}
