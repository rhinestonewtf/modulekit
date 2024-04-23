// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import "../Flashloan/FlashloanCallback.sol";

contract ColdStorageFlashloan is FlashloanCallback {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isInitialized(address smartAccount) external view override returns (bool) { }
}
