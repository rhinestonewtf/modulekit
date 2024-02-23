// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable max-line-length */
/* solhint-disable no-global-import */
import "../utils/Vm.sol";
import { IEntryPoint } from "../../external/ERC4337.sol";
import { SenderCreator } from "@ERC4337/account-abstraction/contracts/core/EntryPoint.sol";
import { EntryPointSimulations } from
    "@ERC4337/account-abstraction/contracts/core/EntryPointSimulations.sol";
import { IEntryPointSimulations } from
    "@ERC4337/account-abstraction/contracts/interfaces/IEntryPointSimulations.sol";

contract EntryPointSimulationsPatch is EntryPointSimulations {
    address _entrypointAddr = address(this);

    SenderCreator _newSenderCreator;

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

address constant ENTRYPOINT_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

function etchEntrypoint() returns (IEntryPoint) {
    address payable entryPoint = payable(address(new EntryPointSimulationsPatch()));
    etch(ENTRYPOINT_ADDR, entryPoint.code);
    EntryPointSimulationsPatch(payable(ENTRYPOINT_ADDR)).init(entryPoint);

    return IEntryPoint(ENTRYPOINT_ADDR);

    // todo: investigate why the following code is not working

    // // Create and etch a new EntryPointSimulations
    // address payable entryPoint = payable(address(new EntryPointSimulations()));
    // etch(ENTRYPOINT_ADDR, entryPoint.code);

    // // Create and etch a new SenderCreator
    // SenderCreator senderCreator = new SenderCreator();
    // address senderCreatorAddr =
    //     address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", ENTRYPOINT_ADDR,
    // hex"01")))));
    // etch(senderCreatorAddr, address(senderCreator).code);

    // return IEntryPoint(ENTRYPOINT_ADDR);
}
