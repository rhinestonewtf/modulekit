// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IBiconomyMetaFactory {
    /// @notice Adds an address to the factory whitelist.
    /// @param factory The address to be whitelisted.
    function addFactoryToWhitelist(address factory) external;

    /// @notice Removes an address from the factory whitelist.
    /// @param factory The address to be removed from the whitelist.
    function removeFactoryFromWhitelist(address factory) external;

    /// @notice Deploys a new Nexus with a specific factory and initialization data.
    /// @param factory The address of the factory to be used for deployment.
    /// @param factoryData The encoded data for the method to be called on the Factory.
    /// @return createdAccount The address of the newly created Nexus account.
    function deployWithFactory(
        address factory,
        bytes calldata factoryData
    )
        external
        payable
        returns (address payable createdAccount);

    /// @notice Checks if an address is whitelisted.
    /// @param factory The address to check.
    /// @return True if the factory is whitelisted, false otherwise.
    function isFactoryWhitelisted(address factory) external view returns (bool);
}
