// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { UserOperation, IEntryPoint, IEntryPointSimulations } from "../../external/ERC4337.sol";
/* solhint-disable no-global-import */
import "./Vm.sol";
import "./Log.sol";
import "./GasCalculations.sol";

library ERC4337Helpers {
    error UserOperationReverted(
        bytes32 userOpHash, address sender, uint256 nonce, bytes revertReason
    );

    function exec4337(UserOperation[] memory userOps, IEntryPoint onEntryPoint) internal {
        // ERC-4337 specs validation
        if (envOr("SIMULATE", false)) {
            simulateUserOps(userOps, onEntryPoint);
        }
        // Record logs to determine if a revert happened
        recordLogs();

        // Get current gas left
        uint256 totalUserOpGas = gasleft();

        // Execute userOps
        address beneficiary = address(0x69);
        onEntryPoint.handleOps(userOps, payable(beneficiary));

        // Get remaining gas
        totalUserOpGas = totalUserOpGas - gasleft();

        // Calculate gas for userOp
        if (envOr("GAS", false)) {
            calculateGas(userOps, onEntryPoint, beneficiary, totalUserOpGas);
        }

        // Parse logs and determine if a revert happened
        VmSafe.Log[] memory logs = getRecordedLogs();
        uint256 expectRevert = getExpectRevert();
        for (uint256 i; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == 0x1c4fada7374c0a9ee8841fc38afe82932dc0f8e69012e927f061a8bae611a201
            ) {
                if (expectRevert != 1) {
                    (uint256 nonce, bytes memory revertReason) =
                        abi.decode(logs[i].data, (uint256, bytes));
                    revert UserOperationReverted(
                        logs[i].topics[1], address(bytes20(logs[i].topics[2])), nonce, revertReason
                    );
                }
            }
        }
        if (expectRevert == 1) revert("UserOperation did not revert");
        writeExpectRevert(0);

        for (uint256 i; i < userOps.length; i++) {
            emit ModuleKitLogs.ModuleKit_Exec4337(userOps[i].sender);
        }
    }

    function exec4337(UserOperation memory userOp, IEntryPoint onEntryPoint) internal {
        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;
        exec4337(userOps, onEntryPoint);
    }

    function simulateUserOps(UserOperation[] memory userOps, IEntryPoint onEntryPoint) internal {
        uint256 snapShotId = snapshot();
        IEntryPointSimulations simulationEntryPoint = IEntryPointSimulations(address(onEntryPoint));
        for (uint256 i; i < userOps.length; i++) {
            UserOperation memory userOp = userOps[i];
            startStateDiffRecording();
            IEntryPointSimulations.ValidationResult memory result =
                simulationEntryPoint.simulateValidation(userOp);
            VmSafe.AccountAccess[] memory accesses = stopAndReturnStateDiff();
            ERC4337SpecsParser.parseValidation(accesses);
        }
        revertTo(snapShotId);
    }

    function calculateGas(
        UserOperation[] memory userOps,
        IEntryPoint onEntryPoint,
        address beneficiary,
        uint256 totalUserOpGas
    )
        internal
    {
        string memory gasIdentifier = getGasIdentifier();
        if (bytes(gasIdentifier).length != 0) {
            bytes memory userOpCalldata =
                abi.encodeWithSelector(onEntryPoint.handleOps.selector, userOps, beneficiary);
            GasParser.parseAndWriteGas(
                userOpCalldata,
                address(onEntryPoint),
                gasIdentifier,
                userOps[0].sender,
                totalUserOpGas
            );
        }
    }

    function map(
        UserOperation[] memory self,
        function(UserOperation memory) returns (UserOperation memory) f
    )
        internal
        returns (UserOperation[] memory)
    {
        UserOperation[] memory result = new UserOperation[](self.length);
        for (uint256 i; i < self.length; i++) {
            result[i] = f(self[i]);
        }
        return result;
    }

    function map(
        UserOperation memory self,
        function(UserOperation memory) internal  returns (UserOperation memory) fn
    )
        internal
        returns (UserOperation memory)
    {
        return fn(self);
    }

    function reduce(
        UserOperation[] memory self,
        function(UserOperation memory, UserOperation memory)  returns (UserOperation memory) f
    )
        internal
        returns (UserOperation memory r)
    {
        r = self[0];
        for (uint256 i = 1; i < self.length; i++) {
            r = f(r, self[i]);
        }
    }

    function array(UserOperation memory op) internal pure returns (UserOperation[] memory ops) {
        ops = new UserOperation[](1);
        ops[0] = op;
    }

    function array(
        UserOperation memory op1,
        UserOperation memory op2
    )
        internal
        pure
        returns (UserOperation[] memory ops)
    {
        ops = new UserOperation[](2);
        ops[0] = op1;
        ops[0] = op2;
    }
}

library ERC4337SpecsParser {
    function parseValidation(VmSafe.AccountAccess[] memory accesses) internal pure {
        validateBannedOpcodes();
        validateBannedStorageLocations(accesses);
        validateDisallowedCalls(accesses);
        validateDisallowedExtOpCodes(accesses);
        validateDisallowedCreate(accesses);
    }

    function validateBannedOpcodes() internal pure {
        // not supported yet
    }

    function validateBannedStorageLocations(VmSafe.AccountAccess[] memory accesses) internal pure {
        // not supported yet
    }

    function validateDisallowedCalls(VmSafe.AccountAccess[] memory accesses) internal pure {
        // not supported yet
    }

    function validateDisallowedExtOpCodes(VmSafe.AccountAccess[] memory accesses) internal pure {
        // not supported yet
    }

    function validateDisallowedCreate(VmSafe.AccountAccess[] memory accesses) internal pure {
        // not supported yet
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
            // todo
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
