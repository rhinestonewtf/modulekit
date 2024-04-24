// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import "../Flashloan/FlashloanCallback.sol";

contract ColdStorageFlashloan is FlashloanCallback {
    using SentinelListLib for SentinelListLib.SentinelList;

    mapping(address account => SentinelListLib.SentinelList) internal whitelist;

    function onInstall(bytes calldata data) external override {
        SentinelListLib.SentinelList storage list = whitelist[msg.sender];
        if (list.alreadyInitialized() && data.length == 0) return;
        list.init();

        address[] memory addresses = abi.decode(data, (address[]));
        uint256 length = addresses.length;
        for (uint256 i; i < length; i++) {
            list.push(addresses[i]);
        }
    }

    function onUninstall(bytes calldata data) external override { }

    function isInitialized(address smartAccount) external view override returns (bool) {
        return whitelist[msg.sender].alreadyInitialized();
    }

    function _isAllowedCallbackSender() internal view virtual override returns (bool) {
        address caller = _msgSender();
        return whitelist[msg.sender].contains(caller);
    }
}
