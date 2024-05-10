// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import "./ProtocolConfig.sol";

abstract contract ModuleRegister is ProtocolConfig {
    event FeeMachineEnabled(IFeeMachine feeMachine, bool enabled);
    event NewFeeMachine(address module, IFeeMachine newFeeMachine);
    event ModuleEnabled(address module, bool enabled);

    error UnauthorizedFeeMachine();
    error UnauthorizedModule(address module);

    mapping(address module => ModuleRecord moduleRecord) internal $module;
    mapping(IFeeMachine feeMachine => bool enabled) internal $enabledFeeMachines;

    // modifier onlyFeeMachine(address module) {
    //     if (msg.sender != address($module[module].feeMachine)) revert UnauthorizedFeeMachine();
    //     _;
    // }

    modifier onlyEnabledModules(address module) {
        if ($module[module].enabled == false) {
            revert UnauthorizedModule(module);
        }
        _;
    }

    modifier onlyEnabledFeeMachines(IFeeMachine feeMachine) {
        if ($enabledFeeMachines[feeMachine] == false) {
            revert UnauthorizedFeeMachine();
        }
        _;
    }

    function enableModule(
        address module,
        address authority,
        bool enabled
    )
        external
        onlyEnabledFeeMachines(IFeeMachine(msg.sender))
    {
        // ensure no other feemachine is responsible for this module
        ModuleRecord storage $moduleRecord = $module[module];

        address currentFeeMachine = address($moduleRecord.feeMachine);

        if (currentFeeMachine != msg.sender || currentFeeMachine != address(0)) {
            $module[module].enabled = enabled;
            $module[module].authority = authority;
            $module[module].feeMachine = IFeeMachine(msg.sender);
            emit ModuleEnabled(module, enabled);
        } else {
            revert UnauthorizedFeeMachine();
        }
    }

    function transferFeeMachineOwnership(address module, IFeeMachine newFeeMachine) external {
        if (
            address($module[module].feeMachine) != msg.sender
                || address(protocolController()) != msg.sender
        ) revert Unauthorized();

        _setFeeMachine({ module: module, newFeeMachine: newFeeMachine });
    }

    function _setFeeMachine(address module, IFeeMachine newFeeMachine) internal {
        $module[module].feeMachine = newFeeMachine;
        emit NewFeeMachine(module, newFeeMachine);
    }

    function authorizeFeeMachine(
        IFeeMachine feeMachine,
        bool enabled
    )
        external
        onlyProtocolController
    {
        if (!feeMachine.supportsInterface(type(IFeeMachine).interfaceId)) {
            revert UnauthorizedFeeMachine();
        }
        $enabledFeeMachines[feeMachine] = enabled;
        emit FeeMachineEnabled(feeMachine, enabled);
    }
}
