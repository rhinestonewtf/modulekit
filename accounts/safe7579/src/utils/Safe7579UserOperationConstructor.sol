// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    IUserOpConstructor, PackedUserOperation
} from "src/interfaces/IUserOperationConstructor.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { Execution, ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";

contract Safe7579UserOpConstructor is IUserOpConstructor {
    IEntryPoint public immutable entryPoint;

    constructor(address _entryPoint) {
        entryPoint = IEntryPoint(_entryPoint);
    }

    function getNonceWithContext(
        address smartAccount,
        bytes calldata permissionsContext
    )
        external
        view
        returns (uint256)
    {
        address validator = address(bytes20(permissionsContext[0:20]));
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        return entryPoint.getNonce(address(smartAccount), key);
    }

    function getCallDataWithContext(
        address smartAccount,
        Execution[] calldata executions,
        bytes calldata permissionsContext
    )
        external
        view
        returns (bytes memory callDataWithContext)
    {
        if (executions.length == 0) {
            revert("No executions provided");
        }
        if (executions.length == 1) {
            callDataWithContext = abi.encodeCall(
                IERC7579Account.execute,
                (
                    ModeLib.encodeSimpleSingle(),
                    ExecutionLib.encodeSingle(
                        executions[0].target, executions[0].value, executions[0].callData
                    )
                )
            );
        } else {
            callDataWithContext = abi.encodeCall(
                IERC7579Account.execute,
                (ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(executions))
            );
        }
        // TODO: add delegatecall, tryExecute and other execution modes handling
    }

    function getSignatureWithContext(
        address smartAccount,
        PackedUserOperation calldata userOp,
        bytes calldata permissionsContext
    )
        external
        returns (bytes memory signature)
    {
        signature = userOp.signature;
    }
}
