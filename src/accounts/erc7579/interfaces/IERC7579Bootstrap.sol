// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IModule } from "../../common/interfaces/IERC7579Module.sol";

// Structs
struct BootstrapConfig {
    address module;
    bytes data;
}

interface IERC7579Bootstrap {
    function singleInitMSA(IModule validator, bytes calldata data) external;

    /**
     * This function is intended to be called by the MSA with a delegatecall.
     * Make sure that the MSA already initilazed the linked lists in the ModuleManager prior to
     * calling this function
     */
    function initMSA(
        BootstrapConfig[] calldata $valdiators,
        BootstrapConfig[] calldata $executors,
        BootstrapConfig calldata _hook,
        BootstrapConfig[] calldata _fallbacks
    )
        external;

    function _getInitMSACalldata(
        BootstrapConfig[] calldata $valdiators,
        BootstrapConfig[] calldata $executors,
        BootstrapConfig calldata _hook,
        BootstrapConfig[] calldata _fallbacks
    )
        external
        view
        returns (bytes memory init);
}
