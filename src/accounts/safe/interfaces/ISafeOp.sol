// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Types
import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";

bytes32 constant SAFE_OP_TYPEHASH =
    0xc03dfc11d8b10bf9cf703d558958c8c42777f785d998c62060d85a4f0ef6ea7f;

interface ISafeOp {
    /**
     * @notice The EIP-712 type-hash for a SafeOp, representing the structure of a User Operation
     * for
     * the Safe.
     *  {address} safe - The address of the safe on which the operation is performed.
     *  {uint256} nonce - A unique number associated with the user operation, preventing replay
     * attacks
     * by ensuring each operation is unique.
     *  {bytes} initCode - The packed encoding of a factory address and its factory-specific data
     * for
     * creating a new Safe account.
     *  {bytes} callData - The bytes representing the data of the function call to be executed.
     *  {uint128} verificationGasLimit - The maximum amount of gas allowed for the verification
     * process.
     *  {uint128} callGasLimit - The maximum amount of gas allowed for executing the function call.
     *  {uint256} preVerificationGas - The amount of gas allocated for pre-verification steps before
     * executing the main operation.
     *  {uint128} maxPriorityFeePerGas - The maximum priority fee per gas that the user is willing
     * to
     * pay for the transaction.
     *  {uint128} maxFeePerGas - The maximum fee per gas that the user is willing to pay for the
     * transaction.
     *  {bytes} paymasterAndData - The packed encoding of a paymaster address and its
     * paymaster-specific
     * data for sponsoring the user operation.
     *  {uint48} validAfter - A timestamp representing from when the user operation is valid.
     *  {uint48} validUntil - A timestamp representing until when the user operation is valid, or 0
     * to
     * indicated "forever".
     *  {address} entryPoint - The address of the entry point that will execute the user operation.
     * @dev When validating the user operation, the signature timestamps are pre-pended to the
     * signature
     * bytes. Equal to:
     * keccak256(
     *     "SafeOp(address safe,uint256 nonce,bytes initCode,bytes callData,uint128
     * verificationGasLimit,uint128 callGasLimit,uint256 preVerificationGas,uint128
     * maxPriorityFeePerGas,uint128 maxFeePerGas,bytes paymasterAndData,uint48 validAfter,uint48
     * validUntil,address entryPoint)"
     * ) = 0xc03dfc11d8b10bf9cf703d558958c8c42777f785d998c62060d85a4f0ef6ea7f
     */
    struct EncodedSafeOpStruct {
        bytes32 typeHash;
        address safe;
        uint256 nonce;
        bytes32 initCodeHash;
        bytes32 callDataHash;
        uint128 verificationGasLimit;
        uint128 callGasLimit;
        uint256 preVerificationGas;
        uint128 maxPriorityFeePerGas;
        uint128 maxFeePerGas;
        bytes32 paymasterAndDataHash;
        uint48 validAfter;
        uint48 validUntil;
        address entryPoint;
    }

    function domainSeparator() external view returns (bytes32);

    function getSafeOp(
        PackedUserOperation calldata userOp,
        address entryPoint
    )
        external
        view
        returns (
            bytes memory operationData,
            uint48 validAfter,
            uint48 validUntil,
            bytes calldata signatures
        );
}
