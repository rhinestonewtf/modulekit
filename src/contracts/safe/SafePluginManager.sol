// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PluginManager} from "../account/core/PluginManagerSingleton.sol";
import "./ISafe.sol";

contract SafePluginManager is PluginManager {
    constructor(address registry) {
        _setRegistry(registry);
    }

    function _execTransationOnSmartAccount(address safe, address to, uint256 value, bytes memory data)
        internal
        override
        returns (bool success, bytes memory)
    {
        success = ISafe(safe).execTransactionFromModule(to, value, data, 0);
    }
}
