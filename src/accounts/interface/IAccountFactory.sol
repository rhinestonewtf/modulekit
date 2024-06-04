// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IAccountFactory {
    function init() public;

    function createAccount(bytes32 salt, bytes memory initCode) public returns (address account);

    function getAddress(bytes32 salt, bytes memory initCode) public view returns (address);

    function getInitData(
        address validator,
        bytes memory initData
    )
        public
        returns (bytes memory init);
}
