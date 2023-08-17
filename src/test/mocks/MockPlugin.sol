// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPluginBase} from "../../contracts/auxiliary/interfaces/IPluginBase.sol";

contract MockPlugin is IPluginBase {
    function pluginFeature() external pure returns (uint256) {
        return 1337;
    }

    function name() external view override returns (string memory name) {}

    function version() external view override returns (string memory version) {}

    function metadataProvider() external view override returns (uint256 providerType, bytes memory location) {}

    function requiresRootAccess() external view override returns (bool requiresRootAccess) {}
}
