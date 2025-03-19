// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { Vm, VmSafe } from "forge-std/Vm.sol";

address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

function makeAddrAndKey(string memory name) returns (address addr, uint256 privateKey) {
    privateKey = uint256(keccak256(abi.encodePacked(name)));
    addr = Vm(VM_ADDR).addr(privateKey);
    Vm(VM_ADDR).label(addr, name);
}

function makeAddr(string memory name) pure returns (address addr) {
    uint256 privateKey = uint256(keccak256(abi.encodePacked(name)));
    addr = Vm(VM_ADDR).addr(privateKey);
    // Vm(VM_ADDR).label(addr, name);
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

function getLabel(address addr) view returns (string memory) {
    return Vm(VM_ADDR).getLabel(addr);
}

function deal(address _addr, uint256 amount) {
    Vm(VM_ADDR).deal(_addr, amount);
}

function expectEmit() {
    Vm(VM_ADDR).expectEmit();
}

function expectRevert() {
    Vm(VM_ADDR).expectRevert();
}

function expectRevert(bytes4 message) {
    Vm(VM_ADDR).expectRevert(message);
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

function startPrank(address _addr) {
    Vm(VM_ADDR).startPrank(_addr);
}

function stopPrank() {
    Vm(VM_ADDR).stopPrank();
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

function snapshot() returns (uint256) {
    return Vm(VM_ADDR).snapshotState();
}

function revertTo(uint256 id) returns (bool) {
    return Vm(VM_ADDR).revertToState(id);
}

function startStateDiffRecording() {
    Vm(VM_ADDR).startStateDiffRecording();
}

function stopAndReturnStateDiff() returns (VmSafe.AccountAccess[] memory) {
    return Vm(VM_ADDR).stopAndReturnStateDiff();
}

function envOr(string memory name, string memory defaultValue) view returns (string memory value) {
    return Vm(VM_ADDR).envOr(name, defaultValue);
}

function envOr(string memory name, bool defaultValue) view returns (bool value) {
    return Vm(VM_ADDR).envOr(name, defaultValue);
}

function setEnv(string memory key, string memory value) {
    Vm(VM_ADDR).setEnv(key, value);
}

function envBool(string memory key) view returns (bool value) {
    return Vm(VM_ADDR).envBool(key);
}

function serializeUint(
    string memory objectKey,
    string memory valueKey,
    uint256 value
)
    returns (string memory json)
{
    return Vm(VM_ADDR).serializeUint(objectKey, valueKey, value);
}

function serializeString(
    string memory objectKey,
    string memory valueKey,
    string memory value
)
    returns (string memory json)
{
    return Vm(VM_ADDR).serializeString(objectKey, valueKey, value);
}

function writeJson(string memory json, string memory path) {
    Vm(VM_ADDR).writeJson(json, path);
}

function readFile(string memory path) view returns (string memory) {
    return Vm(VM_ADDR).readFile(path);
}

function exists(string memory path) view returns (bool) {
    return Vm(VM_ADDR).exists(path);
}

function toString(uint256 input) pure returns (string memory) {
    return Vm(VM_ADDR).toString(input);
}

function toString(int256 input) pure returns (string memory) {
    return Vm(VM_ADDR).toString(input);
}

function toString(bytes memory input) pure returns (string memory) {
    return Vm(VM_ADDR).toString(input);
}

function toString(bytes32 input) pure returns (string memory) {
    bytes memory _bytes = new bytes(32);
    for (uint256 i = 0; i < 32; i++) {
        _bytes[i] = input[i];
    }
    return string(_bytes);
}

function parseJson(string memory json, string memory key) pure returns (bytes memory) {
    return Vm(VM_ADDR).parseJson(json, key);
}

function parseJson(string memory json) pure returns (bytes memory) {
    return Vm(VM_ADDR).parseJson(json);
}

function parseJsonKeys(string memory json, string memory key) pure returns (string[] memory keys) {
    return Vm(VM_ADDR).parseJsonKeys(json, key);
}

function parseUint(string memory stringifiedValue) pure returns (uint256 parsedValue) {
    return Vm(VM_ADDR).parseUint(stringifiedValue);
}

function startMappingRecording() {
    Vm(VM_ADDR).startMappingRecording();
}

function stopMappingRecording() {
    Vm(VM_ADDR).stopMappingRecording();
}

function getMappingKeyAndParentOf(address target, bytes32 slot) returns (bool, bytes32, bytes32) {
    return Vm(VM_ADDR).getMappingKeyAndParentOf(target, slot);
}

function getMappingSlotAt(address target, bytes32 slot, uint256 idx) returns (bytes32) {
    return Vm(VM_ADDR).getMappingSlotAt(target, slot, idx);
}
