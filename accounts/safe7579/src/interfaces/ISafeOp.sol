// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

bytes32 constant SAFE_OP_TYPEHASH =
    0x84aa190356f56b8c87825f54884392a9907c23ee0f8e1ea86336b763faf021bd;

interface ISafeOp {
    struct EncodedSafeOpStruct {
        bytes32 typeHash;
        address safe;
        uint256 nonce;
        bytes32 initCodeHash;
        bytes32 callDataHash;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes32 paymasterAndDataHash;
        uint48 validAfter;
        uint48 validUntil;
        address entryPoint;
    }
}
