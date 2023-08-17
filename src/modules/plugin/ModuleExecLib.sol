// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../auxiliary/interfaces/IPluginBase.sol";
import "../../auxiliary/interfaces/IModuleManager.sol";

library ModuleExecLib {
    function exec(IModuleManager manager, PluginAction memory action) internal {
        PluginAction[] memory actions = new PluginAction[](1);
        actions[0] = action;

        PluginTransaction memory transaction = PluginTransaction({actions: actions, nonce: 0, metadataHash: ""});

        manager.executeTransaction(transaction);
    }

    function exec(IModuleManager manager, address target, bytes memory callData) internal {
        PluginAction memory action = PluginAction({to: payable(target), value: 0, data: callData});
        exec(manager, action);
    }
}
