// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IERC7579Module } from "modulekit/src/external/ERC7579.sol";

contract MockModule is IERC7579Module {
    function isModuleType(uint256) external view returns (bool) {
        return true;
    }

    function onInstall(bytes calldata) external { }

    function onUninstall(bytes calldata) external { }

    function isInitialized(address smartAccount) external view returns (bool) {
        return false;
    }

    receive() external payable { }
}
