// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    IUserOperationBuilder, PackedUserOperation
} from "src/interfaces/IUserOperationBuilder.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { Execution, ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";

contract Safe7579UserOperationBuilder is IUserOperationBuilder {
    IEntryPoint internal immutable _entryPoint;

    constructor(address _entryPointAddress) {
        _entryPoint = IEntryPoint(_entryPointAddress);
    }

    function entryPoint() external view returns (address) {
        return address(_entryPoint);
    }

    function getNonce(
        address smartAccount,
        bytes calldata context
    )
        external
        view
        returns (uint256)
    {
        address validator = address(bytes20(context[0:20]));
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        return _entryPoint.getNonce(address(smartAccount), key);
    }

    function getCallData(
        address smartAccount,
        Execution[] calldata executions,
        bytes calldata context
    )
        external
        view
        returns (bytes memory)
    {
        if (executions.length == 0) {
            revert("No executions provided");
        }
        if (executions.length == 1) {
            return abi.encodeCall(
                IERC7579Account.execute,
                (
                    ModeLib.encodeSimpleSingle(),
                    ExecutionLib.encodeSingle(
                        executions[0].target, executions[0].value, executions[0].callData
                    )
                )
            );
        } else {
            return abi.encodeCall(
                IERC7579Account.execute,
                (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions))
            );
        }
        // TODO: add delegatecall, tryExecute and other execution modes handling
    }

    function getDummySignature(
        address smartAccount,
        Execution[] calldata executions,
        bytes calldata context
    )
        external
        view
        returns (bytes memory signature)
    {
        return context;
    }

    function getSignature(
        address smartAccount,
        PackedUserOperation calldata userOperation,
        bytes calldata context
    )
        external
        view
        returns (bytes memory signature)
    {
        signature = userOperation.signature;
    }
}
