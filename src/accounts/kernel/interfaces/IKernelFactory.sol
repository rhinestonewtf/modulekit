// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { LibClone } from "solady/utils/LibClone.sol";

interface IKernelFactory {
    function createAccount(bytes calldata data, bytes32 salt) external payable returns (address);
    function getAddress(bytes calldata data, bytes32 salt) external returns (address);
}
