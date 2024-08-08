// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    PackedUserOperation,
    IEntryPoint,
    IEntryPointSimulations,
    IStakeManager
} from "../../external/ERC4337.sol";
import { ENTRYPOINT_ADDR } from "../predeploy/EntryPoint.sol";
import "./Vm.sol";
import "./Log.sol";
import "./gas/GasCalculations.sol";
import { Simulator } from "erc4337-validation/Simulator.sol";
import { GasParser } from "./gas/GasParser.sol";
import {
    getSimulateUserOp,
    getExpectRevert,
    writeExpectRevert,
    getGasIdentifier,
    writeGasIdentifier,
    writeInstalledModule,
    getInstalledModules,
    InstalledModule
} from "./Storage.sol";

library ERC4337Helpers {
    using Simulator for PackedUserOperation;

    error UserOperationReverted(
        bytes32 userOpHash, address sender, uint256 nonce, bytes revertReason
    );

    function exec4337(PackedUserOperation[] memory userOps, IEntryPoint onEntryPoint) internal {
        // ERC-4337 specs validation
        if (envOr("SIMULATE", false) || getSimulateUserOp()) {
            userOps[0].simulateUserOp(address(onEntryPoint));
        }
        // Record logs to determine if a revert happened
        recordLogs();

        // Execute userOps
        address payable beneficiary = payable(address(0x69));
        bytes memory userOpCalldata = abi.encodeCall(IEntryPoint.handleOps, (userOps, beneficiary));
        (bool success,) = address(onEntryPoint).call(userOpCalldata);

        uint256 isExpectRevert = getExpectRevert();
        if (isExpectRevert == 0) {
            require(success, "UserOperation execution failed");
        }

        // Parse logs and determine if a revert happened
        VmSafe.Log[] memory logs = getRecordedLogs();
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
                    if (isExpectRevert == 0) {
                        bytes32 userOpHash = logs[i].topics[1];
                        bytes memory revertReason = getUserOpRevertReason(logs, userOpHash);
                        revert UserOperationReverted(
                            userOpHash, address(bytes20(logs[i].topics[2])), nonce, revertReason
                        );
                    } else {
                        writeExpectRevert(0);
                    }
                }
            }
            // ModuleInstalled(uint256, address)
            else if (
                logs[i].topics[0]
                    == 0xd21d0b289f126c4b473ea641963e766833c2f13866e4ff480abd787c100ef123
            ) {
                (uint256 moduleType, address module) = abi.decode(logs[i].data, (uint256, address));
                writeInstalledModule(InstalledModule(moduleType, module));
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
        writeExpectRevert(0);

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

    function exec4337(PackedUserOperation memory userOp, IEntryPoint onEntryPoint) internal {
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        exec4337(userOps, onEntryPoint);
    }

    function getUserOpRevertReason(
        VmSafe.Log[] memory logs,
        bytes32 /* userOpHash */
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
            ) {
                (, revertReason) = abi.decode(logs[i].data, (uint256, bytes));
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
