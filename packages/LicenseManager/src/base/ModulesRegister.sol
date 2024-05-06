// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";
import "../interfaces/IFeeMachine.sol";

abstract contract ModulesRegister is Ownable {
    error UnauthorizedFeeMachine();

    event FeeMachineSet(IFeeMachine feeMachine, bool enabled);

    mapping(address modules => ModuleFee) internal $moduleFees;

    mapping(IFeeMachine feeMachine => bool enabled) internal $feeMachines;

    modifier onlyFeeMachine() {
        if (!$feeMachines[IFeeMachine(msg.sender)]) revert UnauthorizedFeeMachine();
        _;
    }

    function setModule(address module, address developer, bool enabled) public onlyFeeMachine {
        $moduleFees[module] = ModuleFee({
            enabled: enabled,
            feeMachine: IFeeMachine(msg.sender),
            developer: developer
        });
    }

    function setFeeMachine(IFeeMachine feeMachine, bool enabled) external onlyOwner {
        if (!feeMachine.supportsInterface(type(IFeeMachine).interfaceId)) {
            revert UnauthorizedFeeMachine();
        }
        $feeMachines[feeMachine] = enabled;
        emit FeeMachineSet(feeMachine, enabled);
    }
}
