// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";

function getEmptyUserOperation() pure returns (PackedUserOperation memory) {
    return PackedUserOperation({
        sender: address(0),
        nonce: 0,
        initCode: "",
        callData: "",
        accountGasLimits: bytes23(abi.encodePacked(uint128(0), uint128(0))),
        preVerificationGas: 0,
        gasFees: bytes32(abi.encodePacked(uint128(0), uint128(0))),
        paymasterAndData: "",
        signature: ""
    });
}
