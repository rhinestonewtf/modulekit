// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./IExecutor.sol";

contract ExecutorBase is IExecutorBase {
    function name() external view virtual returns (string memory name) {
        name = "ExecutorBase";
    }

    function version() external view virtual returns (string memory version) {
        version = "0.0.1";
    }

    function metadataProvider()
        external
        view
        virtual
        returns (uint256 providerType, bytes memory location)
    {
        providerType = 0;
        location = "";
    }

    function requiresRootAccess() external view virtual returns (bool requiresRootAccess) {
        requiresRootAccess = false;
    }

    function supportsInterface(bytes4 interfaceID) external view virtual override returns (bool) { }
}
