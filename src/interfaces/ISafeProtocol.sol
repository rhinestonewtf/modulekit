// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.18;

struct SafeProtocolAction {
    address payable to;
    uint256 value;
    bytes data;
}

struct SafeTransaction {
    SafeProtocolAction[] actions;
    uint256 nonce;
    bytes32 metadataHash;
}

struct SafeRootAccess {
    SafeProtocolAction action;
    uint256 nonce;
    bytes32 metadataHash;
}

/**
 * @title ISafeProtocolPlugin - An interface that a Safe plugin should implement
 */
interface ISafeProtocolPlugin {
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
