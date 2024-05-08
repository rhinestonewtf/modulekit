// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IProtocolController } from "../interfaces/IProtocolController.sol";

abstract contract LicenseManagerBase is Ownable {
    event FeeMachineEnabled(IFeeMachine feeMachine, bool enabled);
    event NewFeeMachine(address module, IFeeMachine newFeeMachine);
    event ModuleEnabled(address module, bool enabled);

    error UnauthorizedFeeMachine();
    error UnauthorizedModule(address module);

    mapping(address module => ModuleRecord moduleRecord) internal $module;
    mapping(IFeeMachine feeMachine => bool enabled) internal $enabledFeeMachines;

    constructor(IProtocolController protocolController) {
        _initializeOwner(address(protocolController));
    }

    modifier onlyFeeMachine(address module) {
        if (msg.sender != address($module[module].feeMachine)) revert UnauthorizedFeeMachine();
        _;
    }

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

    function _setFeeMachine(address module, IFeeMachine newFeeMachine) internal {
        $module[module].feeMachine = newFeeMachine;
        emit NewFeeMachine(module, newFeeMachine);
    }

    function setModule(
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

    function transferFeeMachine(
        address module,
        IFeeMachine newFeeMachine
    )
        external
        onlyFeeMachine(module)
    {
        _setFeeMachine({ module: module, newFeeMachine: newFeeMachine });
    }

    function authorizeFeeMachine(IFeeMachine feeMachine, bool enabled) external onlyOwner {
        if (!feeMachine.supportsInterface(type(IFeeMachine).interfaceId)) {
            revert UnauthorizedFeeMachine();
        }
        $enabledFeeMachines[feeMachine] = enabled;
        emit FeeMachineEnabled(feeMachine, enabled);
    }
}
