// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    PackedUserOperation,
    IEntryPoint,
    IEntryPointSimulations,
    IStakeManager
} from "../../external/ERC4337.sol";
import { ENTRYPOINT_ADDR } from "../predeploy/EntryPoint.sol";
/* solhint-disable no-global-import */
import "./Vm.sol";
import "./Log.sol";
import "./GasCalculations.sol";
import { Simulator } from "erc4337-validation/Simulator.sol";

library ERC4337Helpers {
    error UserOperationReverted(
        bytes32 userOpHash, address sender, uint256 nonce, bytes revertReason
    );

    function exec4337(PackedUserOperation[] memory userOps, IEntryPoint onEntryPoint) internal {
        // ERC-4337 specs validation
        if (envOr("SIMULATE", false) || getSimulateUserOp()) {
            Simulator.simulateUserOp(userOps[0], address(onEntryPoint));
        }
        // Record logs to determine if a revert happened
        recordLogs();

        // Execute userOps
        address beneficiary = address(0x69);
        onEntryPoint.handleOps(userOps, payable(beneficiary));

        // Parse logs and determine if a revert happened
        VmSafe.Log[] memory logs = getRecordedLogs();
        uint256 isExpectRevert = getExpectRevert();
        uint256 totalUserOpGas = 0;
        for (uint256 i; i < logs.length; i++) {
            // UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)
            if (
                logs[i].topics[0]
                    == 0x49628fd1471006c1482da88028e9ce4dbb080b815c9b0344d39e5a8e6ec1419f
            ) {
                (uint256 nonce, bool success,, uint256 actualGasUsed) =
                    abi.decode(logs[i].data, (uint256, bool, uint256, uint256));
                totalUserOpGas = actualGasUsed;
                if (!success) {
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
        }
        isExpectRevert = getExpectRevert();
        if (isExpectRevert != 0) revert("UserOperation did not revert");
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
        bytes32 userOpHash
    )
        internal
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

    function map(
        PackedUserOperation[] memory self,
        function(PackedUserOperation memory) returns (PackedUserOperation memory) f
    )
        internal
        returns (PackedUserOperation[] memory)
    {
        PackedUserOperation[] memory result = new PackedUserOperation[](self.length);
        for (uint256 i; i < self.length; i++) {
            result[i] = f(self[i]);
        }
        return result;
    }

    function map(
        PackedUserOperation memory self,
        function(PackedUserOperation memory) internal  returns (PackedUserOperation memory) fn
    )
        internal
        returns (PackedUserOperation memory)
    {
        return fn(self);
    }

    function reduce(
        PackedUserOperation[] memory self,
        function(PackedUserOperation memory, PackedUserOperation memory)  returns (PackedUserOperation memory)
            f
    )
        internal
        returns (PackedUserOperation memory r)
    {
        r = self[0];
        for (uint256 i = 1; i < self.length; i++) {
            r = f(r, self[i]);
        }
    }

    function array(PackedUserOperation memory op)
        internal
        pure
        returns (PackedUserOperation[] memory ops)
    {
        ops = new PackedUserOperation[](1);
        ops[0] = op;
    }

    function array(
        PackedUserOperation memory op1,
        PackedUserOperation memory op2
    )
        internal
        pure
        returns (PackedUserOperation[] memory ops)
    {
        ops = new PackedUserOperation[](2);
        ops[0] = op1;
        ops[0] = op2;
    }
}

library GasParser {
    function parseAndWriteGas(
        bytes memory userOpCalldata,
        address entrypoint,
        string memory gasIdentifier,
        address sender,
        uint256 totalUserOpGas
    )
        internal
    {
        string memory fileName = string.concat("./gas_calculations/", gasIdentifier, ".json");

        GasCalculations memory gasCalculations = GasCalculations({
            creation: GasDebug(entrypoint).getGasConsumed(sender, 0),
            validation: GasDebug(entrypoint).getGasConsumed(sender, 1),
            execution: GasDebug(entrypoint).getGasConsumed(sender, 2),
            total: totalUserOpGas,
            arbitrum: getArbitrumL1Gas(userOpCalldata),
            opStack: getOpStackL1Gas(userOpCalldata)
        });

        GasCalculations memory prevGasCalculations;

        if (exists(fileName)) {
            string memory fileContent = readFile(fileName);
            prevGasCalculations = parsePrevGasReport(fileContent);
        }

        string memory finalJson =
            formatGasToWrite(gasIdentifier, prevGasCalculations, gasCalculations);

        writeJson(finalJson, fileName);
        writeGasIdentifier("");
    }

    function formatGasToWrite(
        string memory gasIdentifier,
        GasCalculations memory prevGasCalculations,
        GasCalculations memory gasCalculations
    )
        internal
        returns (string memory finalJson)
    {
        string memory jsonObj = string(abi.encodePacked(gasIdentifier));

        // total gas used
        serializeString(
            jsonObj,
            "Total",
            formatGasValue({ prevValue: prevGasCalculations.total, newValue: gasCalculations.total })
        );

        // ERC-4337 phases gas used
        string memory phasesObj = "phases";
        serializeString(
            phasesObj,
            "Creation",
            formatGasValue({
                prevValue: prevGasCalculations.creation,
                newValue: gasCalculations.creation
            })
        );
        serializeString(
            phasesObj,
            "Validation",
            formatGasValue({
                prevValue: prevGasCalculations.validation,
                newValue: gasCalculations.validation
            })
        );
        string memory phasesOutput = serializeString(
            phasesObj,
            "Execution",
            formatGasValue({
                prevValue: prevGasCalculations.execution,
                newValue: gasCalculations.execution
            })
        );

        // L2-L1 calldata gas used
        string memory l2sObj = "l2s";
        serializeString(
            l2sObj,
            "OP-Stack",
            formatGasValue({
                prevValue: prevGasCalculations.opStack,
                newValue: gasCalculations.opStack
            })
        );
        string memory l2sOutput = serializeString(
            l2sObj,
            "Arbitrum",
            formatGasValue({
                prevValue: prevGasCalculations.arbitrum,
                newValue: gasCalculations.arbitrum
            })
        );

        serializeString(jsonObj, "Phases", phasesOutput);
        finalJson = serializeString(jsonObj, "Calldata", l2sOutput);
    }
}
