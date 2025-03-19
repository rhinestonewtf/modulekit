// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

interface IAccountFactory {
    struct ModuleInitData {
        address module;
        bytes data;
    }

    function init() external;

    function createAccount(
        bytes32 salt,
        bytes memory initCode
    )
        external
        returns (address account);

    function getAddress(bytes32 salt, bytes memory initCode) external returns (address);

    function getInitData(
        address validator,
        bytes memory initData
    )
        external
        returns (bytes memory init);

    function getInitData(
        IAccountFactory.ModuleInitData[] memory validators,
        IAccountFactory.ModuleInitData[] memory executors,
        IAccountFactory.ModuleInitData memory hook,
        IAccountFactory.ModuleInitData[] memory fallbacks
    )
        external
        returns (bytes memory _init);
}
