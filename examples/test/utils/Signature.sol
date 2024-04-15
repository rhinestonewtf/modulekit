// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { Vm } from "forge-std/Vm.sol";

address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

function signHash(uint256 privKey, bytes32 digest) returns (bytes memory) {
    (uint8 v, bytes32 r, bytes32 s) =
        Vm(VM_ADDR).sign(privKey, ECDSA.toEthSignedMessageHash(digest));

    // Sanity checks
    address signer = ecrecover(ECDSA.toEthSignedMessageHash(digest), v, r, s);
    require(signer == Vm(VM_ADDR).addr(privKey), "Invalid signature");

    return abi.encodePacked(r, s, v);
}
