// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import "../Flashloan/FlashloanCallback.sol";

/**
 * @title ColdStorageFlashloan
 * @dev A base for flashloan callback module for cold storage accounts
 * @author Rhinestone
 */
contract ColdStorageFlashloan is FlashloanCallback {
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    // account => whitelist
    mapping(address account => SentinelListLib.SentinelList) internal whitelist;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Called when the module is installed on a smart account
     *
     * @param data The data passed during installation
     */
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

    /**
     * Called when the module is uninstalled from a smart account
     *
     * @param data The data passed during uninstallation
     */
    function onUninstall(bytes calldata data) external override {
        // todo
    }

    /**
     * Check if the module is initialized on a smart account
     *
     * @param smartAccount The smart account address
     *
     * @return True if the module is initialized
     */
    function isInitialized(address smartAccount) external view override returns (bool) {
        return whitelist[msg.sender].alreadyInitialized();
    }

    /**
     * @inheritdoc FlashloanCallback
     */
    function _isAllowedCallbackSender() internal view virtual override returns (bool) {
        address caller = _msgSender();
        return whitelist[msg.sender].contains(caller);
    }
}
