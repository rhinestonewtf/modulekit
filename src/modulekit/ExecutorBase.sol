// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./IExecutor.sol";

abstract contract ExecutorBase is IExecutorBase {
    function name() external view virtual returns (string memory name);

    function version() external view virtual returns (string memory version);

    function metadataProvider()
        external
        view
        virtual
        returns (uint256 providerType, bytes memory location);

    function requiresRootAccess() external view virtual returns (bool requiresRootAccess);

    function supportsInterface(bytes4 interfaceID) external view virtual override returns (bool) {
        return interfaceID == IExecutorBase.name.selector
            || interfaceID == IExecutorBase.version.selector
            || interfaceID == IExecutorBase.metadataProvider.selector
            || interfaceID == IExecutorBase.requiresRootAccess.selector;
    }
}
