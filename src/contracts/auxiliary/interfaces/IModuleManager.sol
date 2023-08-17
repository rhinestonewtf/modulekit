// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../modules/plugin/IPluginBase.sol";

interface IModuleManager {
    function executeTransaction(PluginTransaction calldata transaction) external returns (bytes[] memory data);
}
