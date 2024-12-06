// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { ERC7579FallbackBase } from "../ERC7579FallbackBase.sol";

contract MockFallback is ERC7579FallbackBase {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function targetFunction() external pure returns (bool) {
        return true;
    }

    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_FALLBACK;
    }

    function isInitialized(
        address // smartAccount
    )
        external
        pure
        returns (bool)
    {
        return false;
    }
}
