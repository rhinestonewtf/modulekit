// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC7579Executor {
    error AlreadyInitialized(address smartAccount);
    error NotInitialized(address smartAccount);

    /**
     * @dev This function is called by the smart account during installation of the module
     * @param data arbitrary data that may be required on the module during `onInstall`
     * initialization
     *
     * MUST revert on error (i.e. if module is already enabled)
     */
    function onInstall(bytes calldata data) external;

    /**
     * @dev This function is called by the smart account during uninstallation of the module
     * @param data arbitrary data that may be required on the module during `onUninstall`
     * de-initialization
     *
     * MUST revert on error
     */
    function onUninstall(bytes calldata data) external;

    /**
     * @dev Returns boolean value if module is a certain type
     * @param typeID the module type ID according the ERC-7579 spec
     *
     * MUST return true if the module is of the given type and false otherwise
     */
    function isModuleType(uint256 typeID) external view returns (bool);

    /**
     * @dev Returns bit-encoded integer of the different typeIds of the module
     *
     * MUST return all the bit-encoded typeIds of the module
     */
    // function getModuleTypes() external view returns (EncodedModuleTypes);

    /**
     * @dev Returns if the module was already initialized for a provided smartaccount
     */
    function isInitialized(address smartAccount) external view returns (bool);
}
