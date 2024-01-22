// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/* solhint-disable max-line-length */
/* solhint-disable no-global-import */
import "../utils/Vm.sol";
import { IEntryPoint } from "../../external/ERC4337.sol";
import { EntryPoint, SenderCreator } from "account-abstraction/core/EntryPoint.sol";
import { EntryPointSimulations } from "account-abstraction/core/EntryPointSimulations.sol";
import { IEntryPointSimulations } from "account-abstraction/interfaces/IEntryPointSimulations.sol";

contract EntryPointSimulationsPatch is EntryPointSimulations {
    address _entrypointAddr = address(this);

    function init(address entrypointAddr) public {
        _entrypointAddr = entrypointAddr;
        initSenderCreator();
    }

    function initSenderCreator() internal override {
        //this is the address of the first contract created with CREATE by this address.
        address createdObj = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"d694", _entrypointAddr, hex"01"))))
        );
        _senderCreator = SenderCreator(createdObj);
    }
}

address constant ENTRYPOINT_ADDR = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

contract EntryPointFactory {
    function etchEntrypoint() public returns (IEntryPoint) {
        address payable entryPoint = payable(address(new EntryPointSimulationsPatch()));
        etch(ENTRYPOINT_ADDR, entryPoint.code);
        EntryPointSimulationsPatch(payable(ENTRYPOINT_ADDR)).init(entryPoint);

        return IEntryPoint(ENTRYPOINT_ADDR);
    }

    function getAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
        bytes32 hash =
            keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));

        return address(uint160(uint256(hash)));
    }

    function deploy(bytes memory bytecode, uint256 _salt) public payable {
        address addr;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            addr :=
                create2(
                    callvalue(), // wei sent with current call
                    // Actual code starts after skipping the first 32 bytes
                    add(bytecode, 0x20),
                    mload(bytecode), // Load the size of code contained in the first 32 bytes
                    _salt // Salt from function arguments
                )

            if iszero(extcodesize(addr)) { revert(0, 0) }
        }
    }
}
