// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable no-unused-import */
import { ERC4337Helpers } from "./test/utils/ERC4337Helpers.sol";
import { ERC7579Helpers } from "./test/utils/ERC7579Helpers.sol";
import { sign as vmSign } from "./test/utils/Vm.sol";

function ecdsaSign(uint256 privKey, bytes32 digest) pure returns (bytes memory signature) {
    (uint8 v, bytes32 r, bytes32 s) = vmSign(privKey, digest);
    return abi.encodePacked(r, s, v);
}
