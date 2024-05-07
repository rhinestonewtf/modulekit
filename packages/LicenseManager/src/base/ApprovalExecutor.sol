// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "modulekit/modules/ERC7579ExecutorBase.sol";
import "../DataTypes.sol";
import "../lib/Currency.sol";
import "../interfaces/external/IERC20Minimal.sol";

contract ApprovalExecutor is ERC7579ExecutorBase {
    struct Config {
        bool globalEnabled;
        bool isInitialized;
        mapping(address module => bool enabled) moduleEnabled;
        address[] allEnabledModules;
    }

    mapping(address account => Config config) internal config;

    function onInstall(bytes calldata data) external {
        (bool globalEnabled, address[] memory enabledModules) = abi.decode(data, (bool, address[]));

        config[msg.sender].isInitialized = true;

        if (globalEnabled) {
            config[msg.sender].globalEnabled = true;
        } else {
            uint256 length = enabledModules.length;

            for (uint256 i; i < length; i++) {
                config[msg.sender].moduleEnabled[enabledModules[i]] = true;
                config[msg.sender].allEnabledModules.push(enabledModules[i]);
            }
        }
    }

    function onUninstall(bytes calldata data) external {
        address[] storage allEnabledModules = config[msg.sender].allEnabledModules;

        uint256 length = allEnabledModules.length;

        for (uint256 i; i < length; i++) {
            config[msg.sender].moduleEnabled[allEnabledModules[i]] = false;
        }

        delete config[msg.sender].allEnabledModules;
        delete config[msg.sender].globalEnabled;
        delete config[msg.sender].isInitialized;
    }

    function isModuleType(uint256 typeID) external view returns (bool) {
        if (typeID == 2) return true;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return config[smartAccount].isInitialized;
    }
}
