// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579FallbackBase } from "../Modules.sol";

contract MockFallback is ERC7579FallbackBase {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function targetFunction() external returns (bool) {
        return true;
    }

    function isModuleType(uint256 typeID) external view returns (bool) {
        return typeID == TYPE_FALLBACK;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return false;
    }
}
