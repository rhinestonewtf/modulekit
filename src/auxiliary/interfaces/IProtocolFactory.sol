// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IProtocolFactory {
    function clonePlugin(address implementation, bytes32 salt) external returns (address proxy);

    function clonePlugin(address implementation, bytes calldata initCallData, bytes32 salt)
        external
        returns (address clone, bytes32 saltUsed);

    function getClone(address implementation, bytes32 salt) external view returns (address proxy);
}
