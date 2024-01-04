// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UD60x18, ud, intoUint256 } from "@prb/math/src/UD60x18.sol";
import { PRBMathCastingUint256 } from "@prb/math/src/casting/Uint256.sol";
import { LibZip } from "solady/src/utils/LibZip.sol";

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
