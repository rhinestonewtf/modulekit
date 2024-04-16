// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { SimulateTxAccessor } from
    "@safe-global/safe-contracts/contracts/accessors/SimulateTxAccessor.sol";

contract EventEmitter {
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event ModuleUninstalled(uint256 moduleTypeId, address module);

    function emitModuleInstalled(uint256 moduleTypeId, address module) external {
        emit ModuleInstalled(moduleTypeId, module);
    }

    function emitModuleUninstalled(uint256 moduleTypeId, address module) external {
        emit ModuleUninstalled(moduleTypeId, module);
    }
}

contract ExecMultiCall {
    function execute(Execution[] calldata executions) external returns (bytes[] memory result) {
        uint256 length = executions.length;
        result = new bytes[](length);

        for (uint256 i; i < length; i++) {
            Execution calldata _exec = executions[i];
            result[i] = _execute(_exec.target, _exec.value, _exec.callData);
        }
    }

    function _execute(
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            calldatacopy(result, callData.offset, callData.length)
            if iszero(call(gas(), target, value, result, callData.length, codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }

    function _tryExecute(
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        returns (bool success, bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            calldatacopy(result, callData.offset, callData.length)
            success := iszero(call(gas(), target, value, result, callData.length, codesize(), 0x00))
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }
}

contract DelegateCallTarget is EventEmitter, ExecMultiCall, SimulateTxAccessor { }
