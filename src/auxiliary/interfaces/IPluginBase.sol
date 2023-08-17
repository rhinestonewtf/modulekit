// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.18;

struct PluginAction {
    address payable to;
    uint256 value;
    bytes data;
}

struct PluginTransaction {
    PluginAction[] actions;
    uint256 nonce;
    bytes32 metadataHash;
}

struct PluginRootAccess {
    PluginAction action;
    uint256 nonce;
    bytes32 metadataHash;
}

/**
 * @title ISafeProtocolPlugin - An interface that a Safe plugin should implement
 */
interface IPluginBase {
    /**
     * @notice A funtion that returns name of the plugin
     * @return name string name of the plugin
     */
    function name() external view returns (string memory name);

    /**
     * @notice A funtion that returns version of the plugin
     * @return version string version of the plugin
     */
    function version() external view returns (string memory version);

    /**
     * @notice A funtion that returns version of the plugin.
     *         TODO: Define types of metadata provider and possible values of location in each of the cases.
     * @return providerType uint256 Type of metadata provider
     * @return location bytes
     */
    function metadataProvider() external view returns (uint256 providerType, bytes memory location);

    /**
     * @notice A function that indicates if the plugin requires root access to a Safe.
     * @return requiresRootAccess True if root access is required, false otherwise.
     */
    function requiresRootAccess() external view returns (bool requiresRootAccess);
}

import "./IModuleManager.sol";

library ModuleExecLib {
    function exec(IModuleManager manager, address account, PluginAction memory action) internal {
        PluginAction[] memory actions = new PluginAction[](1);
        actions[0] = action;

        PluginTransaction memory transaction = PluginTransaction({actions: actions, nonce: 0, metadataHash: ""});

        manager.executeTransaction(transaction);
    }

    function exec(IModuleManager manager, address account, address target, bytes memory callData) internal {
        PluginAction memory action = PluginAction({to: payable(target), value: 0, data: callData});
        exec(manager, account, action);
    }
}
