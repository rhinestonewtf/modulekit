// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

import { UserOperation } from "../src/common/erc4337/UserOperation.sol";

function getEmptyUserOp() pure returns (UserOperation memory userOp) {
    userOp = UserOperation({
        sender: address(0),
        nonce: 0,
        initCode: "",
        callData: "",
        callGasLimit: 0,
        verificationGasLimit: 0,
        preVerificationGas: 0,
        maxFeePerGas: 0,
        maxPriorityFeePerGas: 0,
        paymasterAndData: "",
        signature: ""
    });
}
