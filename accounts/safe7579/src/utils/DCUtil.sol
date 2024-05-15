// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Execution } from "../interfaces/IERC7579Account.sol";
import { IModule as IERC7579Module } from "erc7579/interfaces/IERC7579Module.sol";

contract ModuleInstallUtil {
    event ModuleInstalled(uint256 moduleTypeId, address module);
    event ModuleUninstalled(uint256 moduleTypeId, address module);

    function installModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata initData
    )
        external
    {
        IERC7579Module(module).onInstall(initData);
        emit ModuleInstalled(moduleTypeId, address(module));
    }

    function unInstallModule(
        uint256 moduleTypeId,
        address module,
        bytes calldata initData
    )
        external
    {
        IERC7579Module(module).onUninstall(initData);
        emit ModuleUninstalled(moduleTypeId, address(module));
    }
}

contract BatchedExecUtil {
    function tryExecute(Execution[] calldata executions) external returns (bool success) {
        uint256 length = executions.length;

        for (uint256 i; i < length; i++) {
            Execution calldata _exec = executions[i];
            (success,) = _tryExecute(_exec.target, _exec.value, _exec.callData);
        }
    }

    function execute(Execution[] calldata executions) external {
        uint256 length = executions.length;

        for (uint256 i; i < length; i++) {
            Execution calldata _exec = executions[i];
            _execute(_exec.target, _exec.value, _exec.callData);
        }
    }

    function executeReturn(Execution[] calldata executions)
        external
        returns (bytes[] memory result)
    {
        uint256 length = executions.length;
        result = new bytes[](length);

        for (uint256 i; i < length; i++) {
            Execution calldata _exec = executions[i];
            result[i] = _execute(_exec.target, _exec.value, _exec.callData);
        }
    }

    function tryExecuteReturn(Execution[] calldata executions)
        external
        returns (bool[] memory success, bytes[] memory result)
    {
        uint256 length = executions.length;
        result = new bytes[](length);
        success = new bool[](length);

        for (uint256 i; i < length; i++) {
            Execution calldata _exec = executions[i];
            (success[i], result[i]) = _tryExecute(_exec.target, _exec.value, _exec.callData);
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
        // solhint-disable-next-line no-inline-assembly
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
        // solhint-disable-next-line no-inline-assembly
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

contract Safe7579DCUtil is ModuleInstallUtil, BatchedExecUtil {
    function staticCall(address target, bytes memory data) external view {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            let success := staticcall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
            returndatacopy(ptr, 0x00, returndatasize())
            if success { return(ptr, returndatasize()) }
            revert(ptr, returndatasize())
        }
    }
}
