// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { UD60x18, ud, intoUint256 } from "@prb/math/src/UD60x18.sol";
import { PRBMathCastingUint256 } from "@prb/math/src/casting/Uint256.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { parseJson, toString } from "./Vm.sol";

/// @title GasCalculations
/// @dev This contract is used for calculating gas consumption in different phases of a transaction.
struct GasCalculations {
    uint256 creation;
    uint256 validation;
    uint256 execution;
    uint256 total;
    uint256 arbitrum;
    uint256 opStack;
}

/// @notice Calculate the gas cost of calldata.
/// @param data The calldata to be sent.
/// @return calldataGas The gas cost of the calldata.
function getCallDataGas(bytes memory data) pure returns (uint256 calldataGas) {
    for (uint256 i = 0; i < data.length; i++) {
        if (data[i] == 0x00) {
            calldataGas += 4;
        } else {
            calldataGas += 16;
        }
    }
}

/// @notice Calculate the gas cost of calldata on Arbitrum L1.
/// @param data The calldata to be sent.
/// @return calldataGas The gas cost of the calldata on Arbitrum L1.
function getArbitrumL1Gas(bytes memory data) pure returns (uint256 calldataGas) {
    bytes memory compressed = LibZip.flzCompress(data);
    calldataGas = getCallDataGas(compressed);
}

/// @notice Calculate the gas cost of calldata on OpStack L1.
/// @param data The calldata to be sent.
/// @return calldataGas The gas cost of the calldata on OpStack L1.
function getOpStackL1Gas(bytes memory data) pure returns (uint256 calldataGas) {
    uint256 opStackConstant = 2028;
    UD60x18 opStackScalar = ud(0.684e18);

    calldataGas = intoUint256(
        PRBMathCastingUint256.intoUD60x18(getCallDataGas(data)).mul(opStackScalar)
    ) + opStackConstant;
}

/// @notice Parse the previous gas report from a file.
/// @param fileContent The content of the file.
/// @return prevGasCalculations The previous gas calculations.
function parsePrevGasReport(string memory fileContent)
    pure
    returns (GasCalculations memory prevGasCalculations)
{
    prevGasCalculations.total = parseUintFromASCII(parseJson(fileContent, ".Total"));
    prevGasCalculations.creation = parseUintFromASCII(parseJson(fileContent, ".Phases.Creation"));
    prevGasCalculations.validation =
        parseUintFromASCII(parseJson(fileContent, ".Phases.Validation"));
    prevGasCalculations.execution = parseUintFromASCII(parseJson(fileContent, ".Phases.Execution"));
    prevGasCalculations.arbitrum = parseUintFromASCII(parseJson(fileContent, ".Calldata.Arbitrum"));
    prevGasCalculations.opStack = parseUintFromASCII(parseJson(fileContent, ".Calldata.OP-Stack"));
}

/// @notice Parse a uint256 from ASCII.
/// @param ascii The ASCII to be parsed.
/// @return _ret The parsed uint256.
function parseUintFromASCII(bytes memory ascii) pure returns (uint256 _ret) {
    bytes memory prevTotal;
    uint256 offset = ascii.length > 32 ? 32 : 0;
    for (uint256 i; i < ascii.length; i++) {
        if (ascii[i] == 0x28) {
            break;
        } else {
            if (i >= offset) {
                prevTotal = abi.encodePacked(prevTotal, ascii[i]);
            }
        }
    }
    uint256 j = 1;
    for (uint256 i = prevTotal.length - 1; i > 0; i--) {
        if (uint8(prevTotal[i]) >= 48 && uint8(prevTotal[i]) <= 57) {
            _ret += (uint8(prevTotal[i]) - 48) * j;
            j *= 10;
        }
    }
}

/// @notice Format the gas value.
/// @param prevValue The previous gas value.
/// @param newValue The new gas value.
/// @return formattedValue The formatted gas value.
function formatGasValue(
    uint256 prevValue,
    uint256 newValue
)
    pure
    returns (string memory formattedValue)
{
    if (prevValue == 0) {
        formattedValue = string.concat(formatGas(int256(newValue)), " gas");
    } else {
        formattedValue = string.concat(
            formatGas(int256(newValue)),
            " gas (diff: ",
            formatGas(int256(newValue) - int256(prevValue)),
            ")"
        );
    }
}

/// @notice Format the gas value with underscores for readability.
/// @param value The gas value to be formatted.
/// @return The formatted gas value.
function formatGas(int256 value) pure returns (string memory) {
    string memory str = toString(value);
    bytes memory bStr = bytes(str);
    bytes memory result = new bytes(bStr.length + (bStr.length - 1) / 3);

    uint256 j = result.length;
    for (uint256 i = 0; i < bStr.length; i++) {
        if (i > 0 && i % 3 == 0) {
            result[--j] = "_";
        }
        result[--j] = bStr[bStr.length - i - 1];
    }

    return string(result);
}

interface GasDebug {
    function getGasConsumed(address account, uint256 phase) external view returns (uint256);
}
