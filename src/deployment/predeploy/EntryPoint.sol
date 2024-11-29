// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Utils
import { etch } from "../../test/utils/Vm.sol";

// Interfaces
import { IEntryPoint } from "../../external/ERC4337.sol";

// External Dependencies
import { SenderCreator } from "@ERC4337/account-abstraction/contracts/core/EntryPoint.sol";
import { EntryPointSimulations } from
    "@ERC4337/account-abstraction/contracts/core/EntryPointSimulations.sol";

contract EntryPointSimulationsPatch is EntryPointSimulations {
    address public _entrypointAddr = address(this);

    SenderCreator public _newSenderCreator;

    function init(address entrypointAddr) public {
        _entrypointAddr = entrypointAddr;
        initSenderCreator();
    }

    function initSenderCreator() internal override {
        //this is the address of the first contract created with CREATE by this address.
        address createdObj = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"d694", _entrypointAddr, hex"01"))))
        );
        _newSenderCreator = SenderCreator(createdObj);
    }

    function senderCreator() internal view virtual override returns (SenderCreator) {
        return _newSenderCreator;
    }
}

/// @dev Preset entrypoint address
address constant ENTRYPOINT_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

function etchEntrypoint() returns (IEntryPoint) {
    address payable entryPoint = payable(address(new EntryPointSimulationsPatch()));
    etch(ENTRYPOINT_ADDR, entryPoint.code);
    EntryPointSimulationsPatch(payable(ENTRYPOINT_ADDR)).init(entryPoint);

    return IEntryPoint(ENTRYPOINT_ADDR);
}
