// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UD60x18, ud, intoUint256 } from "@prb/math/src/UD60x18.sol";
import { PRBMathCastingUint256 } from "@prb/math/src/casting/Uint256.sol";
import { LibZip } from "solady/src/utils/LibZip.sol";
import { parseJson, toString } from "./Vm.sol";

struct GasCalculations {
    uint256 creation;
    uint256 validation;
    uint256 execution;
    uint256 total;
    uint256 arbitrum;
    uint256 opStack;
}

function getCallDataGas(bytes memory data) pure returns (uint256 calldataGas) {
    for (uint256 i = 0; i < data.length; i++) {
        if (data[i] == 0x00) {
            calldataGas += 4;
        } else {
            calldataGas += 16;
        }
    }
}

function getArbitrumL1Gas(bytes memory data) pure returns (uint256 calldataGas) {
    bytes memory compressed = LibZip.flzCompress(data);
    calldataGas = getCallDataGas(compressed);
}

function getOpStackL1Gas(bytes memory data) pure returns (uint256 calldataGas) {
    uint256 opStackConstant = 2028;
    UD60x18 opStackScalar = ud(0.684e18);

    calldataGas = intoUint256(
        PRBMathCastingUint256.intoUD60x18(getCallDataGas(data)).mul(opStackScalar)
    ) + opStackConstant;
}

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

function formatGasValue(
    uint256 prevValue,
    uint256 newValue
)
    pure
    returns (string memory formattedValue)
{
    if (prevValue == 0) {
        formattedValue = string.concat(toString(newValue), " gas");
    } else {
        formattedValue = string.concat(
            toString(newValue), " gas (diff: ", toString(int256(newValue) - int256(prevValue)), ")"
        );
    }
}

interface GasDebug {
    function getGasConsumed(address account, uint256 phase) external view returns (uint256);
}
