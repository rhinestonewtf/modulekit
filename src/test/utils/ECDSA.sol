// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Utils
import { sign as vmSign } from "./Vm.sol";

function ecdsaSign(uint256 privKey, bytes32 digest) pure returns (bytes memory signature) {
    (uint8 v, bytes32 r, bytes32 s) = vmSign(privKey, digest);
    return abi.encodePacked(r, s, v);
}
