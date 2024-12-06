// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Utils
import "../Vm.sol";
import "../Log.sol";

// Dependencies
import "./GasCalculations.sol";
import { writeGasIdentifier } from "../Storage.sol";

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
