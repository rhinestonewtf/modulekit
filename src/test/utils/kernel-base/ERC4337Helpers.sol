// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { UserOperation } from "src/common/erc4337/UserOperation.sol";
import { IEntryPoint } from "src/common/erc4337/IEntryPoint.sol";

library ERC4337Wrappers {
    function getPartialUserOp(
        address smartAccount,
        IEntryPoint entrypoint,
        bytes memory callData,
        bytes memory initCode
    )
        internal
        view
        returns (UserOperation memory)
    {
        // // Get Safe initCode if not deployed already
        // bytes memory initCode = isDeployed(smartAccount) ? bytes("") : safeInitCode(instance);

        // Get nonce from Entrypoint
        uint256 nonce = entrypoint.getNonce(smartAccount, 0);

        UserOperation memory userOp = UserOperation({
            sender: smartAccount,
            nonce: nonce,
            initCode: initCode,
            callData: callData,
            callGasLimit: 2e6,
            verificationGasLimit: 2e6,
            preVerificationGas: 2e6,
            maxFeePerGas: 1,
            maxPriorityFeePerGas: 1,
            paymasterAndData: bytes(""),
            signature: bytes("")
        });
        return userOp;
    }
}
