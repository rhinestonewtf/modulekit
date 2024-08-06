// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct BootstrapConfig {
    address module;
    bytes data;
}

interface INexusBootstrap {
    /// @notice Initializes the Nexus account with multiple modules.
    /// @dev Intended to be called by the Nexus with a delegatecall.
    /// @param validators The configuration array for validator modules.
    /// @param executors The configuration array for executor modules.
    /// @param hook The configuration for the hook module.
    /// @param fallbacks The configuration array for fallback handler modules.
    function initNexus(
        BootstrapConfig[] calldata validators,
        BootstrapConfig[] calldata executors,
        BootstrapConfig calldata hook,
        BootstrapConfig[] calldata fallbacks
    )
        external;

    /// @notice Initializes the Nexus account with a scoped set of modules.
    /// @dev Intended to be called by the Nexus with a delegatecall.
    /// @param validators The configuration array for validator modules.
    /// @param hook The configuration for the hook module.
    function initNexusScoped(
        BootstrapConfig[] calldata validators,
        BootstrapConfig calldata hook
    )
        external;

    /// @notice Prepares calldata for the initNexus function.
    /// @param validators The configuration array for validator modules.
    /// @param executors The configuration array for executor modules.
    /// @param hook The configuration for the hook module.
    /// @param fallbacks The configuration array for fallback handler modules.
    /// @return init The prepared calldata for initNexus.
    function getInitNexusCalldata(
        BootstrapConfig[] calldata validators,
        BootstrapConfig[] calldata executors,
        BootstrapConfig calldata hook,
        BootstrapConfig[] calldata fallbacks
    )
        external
        view
        returns (bytes memory init);

    /// @notice Prepares calldata for the initNexusScoped function.
    /// @param validators The configuration array for validator modules.
    /// @param hook The configuration for the hook module.
    /// @return init The prepared calldata for initNexusScoped.
    function getInitNexusScopedCalldata(
        BootstrapConfig[] calldata validators,
        BootstrapConfig calldata hook
    )
        external
        view
        returns (bytes memory init);

    /// @notice Prepares calldata for the initNexusWithSingleValidator function.
    /// @param validator The configuration for the validator module.
    /// @return init The prepared calldata for initNexusWithSingleValidator.
    function getInitNexusWithSingleValidatorCalldata(BootstrapConfig calldata validator)
        external
        view
        returns (bytes memory init);
}
