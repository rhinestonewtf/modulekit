// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { Vm } from "forge-std/Vm.sol";

address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

function signHash(uint256 privKey, bytes32 digest) returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) =
        Vm(VM_ADDR).sign(privKey, ECDSA.toEthSignedMessageHash(digest));
    return abi.encodePacked(r, s, v);
}
