// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Types
import {
    PackedUserOperation,
    IEntryPoint,
    IEntryPointSimulations,
    IStakeManager
} from "../../external/ERC4337.sol";
import { ExecutionReturnData } from "../RhinestoneModuleKit.sol";

// Deployments
import { ENTRYPOINT_ADDR } from "../../deployment/predeploy/EntryPoint.sol";

// Utils
import "./Vm.sol";
import "./Log.sol";

// Dependencies
import "./gas/GasCalculations.sol";
import { GasParser } from "./gas/GasParser.sol";
import {
    getSimulateUserOp,
    getExpectRevert,
    getExpectRevertMessage,
    clearExpectRevert,
    getGasIdentifier,
    writeGasIdentifier,
    writeInstalledModule,
    getInstalledModules,
    removeInstalledModule,
    InstalledModule
} from "./Storage.sol";

// External Dependencies
import { Simulator } from "erc4337-validation/Simulator.sol";

/// @notice A library that contains helper functions for ERC-4337 operations
library ERC4337Helpers {
    using Simulator for PackedUserOperation;

    error UserOperationReverted(
        bytes32 userOpHash, address sender, string senderLabel, uint256 nonce, bytes revertReason
    );
    error InvalidRevertMessage(bytes4 expected, bytes4 reason);
    error InvalidRevertMessageBytes(bytes expected, bytes reason);

    function exec4337(
        PackedUserOperation[] memory userOps,
        IEntryPoint onEntryPoint
    )
        internal
        returns (ExecutionReturnData memory executionData)
    {
        uint256 isExpectRevert = getExpectRevert();

        // ERC-4337 specs validation
        if (envOr("SIMULATE", false) || getSimulateUserOp()) {
            bool simulationSuccess = userOps[0].simulateUserOp(address(onEntryPoint));

            if (isExpectRevert == 0) {
                require(simulationSuccess, "UserOperation simulation failed");
            }
        }
        // Record logs to determine if a revert happened
        recordLogs();

        // Execute userOps
        address payable beneficiary = payable(address(0x69));
        bytes memory userOpCalldata = abi.encodeCall(IEntryPoint.handleOps, (userOps, beneficiary));
        (bool success, bytes memory returnData) = address(onEntryPoint).call(userOpCalldata);

        if (isExpectRevert == 0) {
            require(success, "UserOperation execution failed");
        } else if (isExpectRevert == 2 && !success) {
            checkRevertMessage(returnData);
        }

        // Parse logs and determine if a revert happened
        VmSafe.Log[] memory logs = getRecordedLogs();
        executionData = ExecutionReturnData(logs);
        uint256 totalUserOpGas = 0;
        for (uint256 i; i < logs.length; i++) {
            // UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)
            if (
                logs[i].topics[0]
                    == 0x49628fd1471006c1482da88028e9ce4dbb080b815c9b0344d39e5a8e6ec1419f
            ) {
                (uint256 nonce, bool userOpSuccess,, uint256 actualGasUsed) =
                    abi.decode(logs[i].data, (uint256, bool, uint256, uint256));
                totalUserOpGas = actualGasUsed;
                if (!userOpSuccess) {
                    bytes32 userOpHash = logs[i].topics[1];
                    if (isExpectRevert == 0) {
                        bytes memory revertReason = getUserOpRevertReason(logs, userOpHash);
                        address account = address(bytes20(logs[i].topics[2]));
                        revert UserOperationReverted(
                            userOpHash, account, getLabel(account), nonce, revertReason
                        );
                    } else {
                        if (isExpectRevert == 2) {
                            checkRevertMessage(getUserOpRevertReason(logs, userOpHash));
                        }
                        clearExpectRevert();
                    }
                }
            }
            // ModuleInstalled(uint256, address)
            else if (
                logs[i].topics[0]
                    == 0xd21d0b289f126c4b473ea641963e766833c2f13866e4ff480abd787c100ef123
            ) {
                (uint256 moduleType, address module) = abi.decode(logs[i].data, (uint256, address));
                writeInstalledModule(InstalledModule(moduleType, module), logs[i].emitter);
            }
            // ModuleUninstalled(uint256, address)
            else if (
                logs[i].topics[0]
                    == 0x341347516a9de374859dfda710fa4828b2d48cb57d4fbe4c1149612b8e02276e
            ) {
                (uint256 moduleType, address module) = abi.decode(logs[i].data, (uint256, address));
                // Get all installed modules
                InstalledModule[] memory installedModules = getInstalledModules(logs[i].emitter);
                // Remove the uninstalled module from the list of installed modules
                for (uint256 j; j < installedModules.length; j++) {
                    if (
                        installedModules[j].moduleAddress == module
                            && installedModules[j].moduleType == moduleType
                    ) {
                        removeInstalledModule(j, logs[i].emitter);
                        break;
                    }
                }
            }
        }
        isExpectRevert = getExpectRevert();
        if (isExpectRevert != 0) {
            if (success) {
                revert("UserOperation did not revert");
            } else {
                require(!success, "UserOperation execution did not fail as expected");
            }
        }
        clearExpectRevert();

        // Calculate gas for userOp
        string memory gasIdentifier = getGasIdentifier();
        if (
            envOr("GAS", false) && bytes(gasIdentifier).length > 0
                && bytes(gasIdentifier).length < 50
        ) {
            calculateGas(userOps, onEntryPoint, beneficiary, gasIdentifier, totalUserOpGas);
        }

        for (uint256 i; i < userOps.length; i++) {
            emit ModuleKitLogs.ModuleKit_Exec4337(userOps[i].sender);
        }
    }

    function exec4337(
        PackedUserOperation memory userOp,
        IEntryPoint onEntryPoint
    )
        internal
        returns (ExecutionReturnData memory logs)
    {
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        return exec4337(userOps, onEntryPoint);
    }

    function getUserOpRevertReason(
        VmSafe.Log[] memory logs,
        bytes32 userOpHash
    )
        internal
        pure
        returns (bytes memory revertReason)
    {
        for (uint256 i; i < logs.length; i++) {
            // UserOperationRevertReason(bytes32,address,uint256,bytes)
            if (
                logs[i].topics[0]
                    == 0x1c4fada7374c0a9ee8841fc38afe82932dc0f8e69012e927f061a8bae611a201
                    && logs[i].topics[1] == userOpHash
            ) {
                (, revertReason) = abi.decode(logs[i].data, (uint256, bytes));
            }
        }
    }

    function checkRevertMessage(bytes memory actualReason) internal view {
        bytes memory revertMessage = getExpectRevertMessage();
        if (actualReason.length >= 4) {
            bytes4 actual = bytes4(actualReason);
            bytes4 expected = bytes4(revertMessage);
            if (actual == bytes4(0x65c8fd4d)) {
                return parseFailedOpWithRevert(actualReason, revertMessage);
            } else if (actual != expected) {
                revert InvalidRevertMessageBytes(revertMessage, actualReason);
            }
            return;
        }
        if (revertMessage.length != actualReason.length) {
            revert InvalidRevertMessageBytes(revertMessage, actualReason);
        }
    }

    function parseFailedOpWithRevert(
        bytes memory actualReason,
        bytes memory revertMessage
    )
        internal
        pure
    {
        uint256 bytesOffset;
        assembly {
            let ptr := add(actualReason, 0x20) // to data start
            ptr := add(ptr, 0x04) // skip selector
            ptr := add(ptr, 0x40) // skip two params
            bytesOffset := mload(ptr)
        }

        bytes memory actual;
        assembly {
            let ptr := add(actualReason, 0x20) // to data start
            ptr := add(ptr, 0x04) // skip selector
            ptr := add(ptr, bytesOffset) // go to bytes position
            let innerLength := mload(ptr) // load length of inner bytes

            // Allocate memory for actual bytes
            actual := mload(0x40)
            mstore(actual, innerLength) // store length

            // Copy the data
            let srcPtr := add(ptr, 0x20)
            let destPtr := add(actual, 0x20)
            mstore(destPtr, mload(srcPtr))

            // Update free memory pointer
            mstore(0x40, add(add(actual, 0x20), innerLength))
        }

        // If the length of the revert message is 4, just compare the selectors
        if (revertMessage.length == 4) {
            bytes4 expected = bytes4(revertMessage);
            if (expected != bytes4(actual)) {
                revert InvalidRevertMessage(expected, bytes4(actual));
            }
        }
        // Otherwise, compare the actual bytes
        else {
            if (keccak256(actual) != keccak256(revertMessage)) {
                revert InvalidRevertMessageBytes(revertMessage, actual);
            }
        }
    }

    function calculateGas(
        PackedUserOperation[] memory userOps,
        IEntryPoint onEntryPoint,
        address beneficiary,
        string memory gasIdentifier,
        uint256 totalUserOpGas
    )
        internal
    {
        bytes memory userOpCalldata =
            abi.encodeWithSelector(onEntryPoint.handleOps.selector, userOps, beneficiary);
        GasParser.parseAndWriteGas(
            userOpCalldata, address(onEntryPoint), gasIdentifier, userOps[0].sender, totalUserOpGas
        );
    }
}
