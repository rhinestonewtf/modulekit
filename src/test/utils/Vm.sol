// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Vm, VmSafe } from "forge-std/Vm.sol";

address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

function makeAddrAndKey(string memory name) returns (address addr, uint256 privateKey) {
    privateKey = uint256(keccak256(abi.encodePacked(name)));
    addr = Vm(VM_ADDR).addr(privateKey);
    Vm(VM_ADDR).label(addr, name);
}

function makeAddr(string memory name) returns (address addr) {
    uint256 privateKey = uint256(keccak256(abi.encodePacked(name)));
    addr = Vm(VM_ADDR).addr(privateKey);
    Vm(VM_ADDR).label(addr, name);
}

function getAddr(uint256 pk) pure returns (address) {
    return Vm(VM_ADDR).addr(pk);
}

function sign(uint256 pk, bytes32 msgHash) pure returns (uint8 v, bytes32 r, bytes32 s) {
    return Vm(VM_ADDR).sign(pk, msgHash);
}

function etch(address target, bytes memory runtimeBytecode) {
    Vm(VM_ADDR).etch(target, runtimeBytecode);
}

function label(address _addr, string memory _label) {
    Vm(VM_ADDR).label(_addr, _label);
}

function deal(address _addr, uint256 amount) {
    Vm(VM_ADDR).deal(_addr, amount);
}

function expectEmit() {
    Vm(VM_ADDR).expectEmit();
}

function recordLogs() {
    Vm(VM_ADDR).recordLogs();
}

function getRecordedLogs() returns (VmSafe.Log[] memory) {
    return Vm(VM_ADDR).getRecordedLogs();
}

function prank(address _addr) {
    Vm(VM_ADDR).prank(_addr);
}

function accesses(address _addr) returns (bytes32[] memory, bytes32[] memory) {
    return Vm(VM_ADDR).accesses(_addr);
}

function store(address account, bytes32 key, bytes32 entry) {
    Vm(VM_ADDR).store(account, key, entry);
}

function record() {
    Vm(VM_ADDR).record();
}

function load(address account, bytes32 key) view returns (bytes32) {
    return Vm(VM_ADDR).load(account, key);
}
