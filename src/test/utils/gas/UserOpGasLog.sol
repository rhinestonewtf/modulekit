// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Types
import {
    PackedUserOperation,
    EntryPointSimulations,
    IEntryPointSimulations
} from "src/external/ERC4337.sol";

// Utils
import "../Log.sol";

contract UserOpGasLog {
    EntryPointSimulations public immutable simulation = new EntryPointSimulations();

    struct GasLog {
        uint256 gasValidation;
        uint256 gasExecution;
    }

    mapping(bytes32 userOpHash => GasLog log) internal _log;

    function getLog(bytes32 userOpHash)
        external
        view
        returns (uint256 gasValidation, uint256 gasExecution)
    {
        GasLog memory log = _log[userOpHash];
        return (log.gasValidation, log.gasExecution);
    }

    function calcValidationGas(
        PackedUserOperation memory userOp,
        bytes32 userOpHash,
        address, /* sender */
        bytes memory /* initCode */
    )
        external
        returns (uint256 gasValidation)
    {
        IEntryPointSimulations.ValidationResult memory validationResult =
            simulation.simulateValidation(userOp);

        gasValidation = validationResult.returnInfo.preOpGas;

        _log[userOpHash].gasValidation = gasValidation;
    }

    function calcExecutionGas(
        PackedUserOperation memory userOp,
        bytes32 userOpHash,
        address sender,
        bytes memory initCode
    )
        external
        returns (uint256 gasExecution)
    {
        IEntryPointSimulations.ExecutionResult memory executionResult =
            simulation.simulateHandleOp(userOp, sender, initCode);

        gasExecution = executionResult.paid;
        // gasValidation = executionResult.gasUsedInValidation;

        // _log[userOpHash].gasValidation = executionResult.gasUsedInValidation;
        _log[userOpHash].gasExecution = gasExecution;
    }
}
