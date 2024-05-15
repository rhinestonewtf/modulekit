// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PackedUserOperation } from
    "@ERC4337/account-abstraction/contracts/core/UserOperationLib.sol";
import { Execution } from "./IERC7579Account.sol";

interface IUserOperationBuilder {
// /**
//  * @dev Returns the ERC-4337 EntryPoint that the account implementation
//  * supports.
//  */
// function entryPoint() external view returns (address);

// /**
//  * @dev Returns the nonce to use for the UserOp, given the context.
//  * @param smartAccount is the address of the UserOp sender.
//  * @param context is the data required for the UserOp builder to
//  * properly compute the requested field for the UserOp.
//  */
// function getNonce(
//     address smartAccount,
//     bytes calldata context
// )
//     external
//     view
//     returns (uint256);

// /**
//  * @dev Returns the calldata for the UserOp, given the context and
//  * the executions.
//  * @param smartAccount is the address of the UserOp sender.
//  * @param executions are (destination, value, callData) tuples that
//  * the UserOp wants to execute.  It's an array so the UserOp can
//  * batch executions.
//  * @param context is the data required for the UserOp builder to
//  * properly compute the requested field for the UserOp.
//  */
// function getCallData(
//     address smartAccount,
//     Execution[] calldata executions,
//     bytes calldata context
// )
//     external
//     view
//     returns (bytes memory);

// /**
//  * @dev Returns the dummy signature for the UserOp, given the context
//  * and the executions.
//  * @param smartAccount is the address of the UserOp sender.
//  * @param executions are (destination, value, callData) tuples that
//  * the UserOp wants to execute.  It's an array so the UserOp can
//  * batch executions.
//  * @param context is the data required for the UserOp builder to
//  * properly compute the requested field for the UserOp.
//  */
// function getDummySignature(
//     address smartAccount,
//     Execution[] calldata executions,
//     bytes calldata context
// )
//     external
//     view
//     returns (bytes memory signature);

// /**
//  * @dev Returns a correctly encoded signature, given a UserOp that
//  * has been correctly filled out except for the signature field.
//  * @param smartAccount is the address of the UserOp sender.
//  * @param userOperation is the UserOp.  Every field of the UserOp should
//  * be valid except for the signature field.  The "PackedUserOperation"
//  * struct is as defined in ERC-4337.
//  * @param context is the data required for the UserOp builder to
//  * properly compute the requested field for the UserOp.
//  */
// function getSignature(
//     address smartAccount,
//     PackedUserOperation calldata userOperation,
//     bytes calldata context
// )
//     external
//     view
//     returns (bytes memory signature);
}
