// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {AccountInstance} from "./IAccountFactory.sol";

library ERC4337Wrappers {
    function getSafe4337TxCalldata(
        AccountInstance memory instance,
        address target,
        uint256 value,
        bytes memory data,
        uint8 operation // {0: Call, 1: DelegateCall}
    ) internal returns (bytes memory) {
        // Get Safe address
        address sender = address(instance.account);

        // Get nonce from Entrypoint
        uint256 nonce = instance.entrypoint.getNonce(sender, 0);

        return abi.encodeWithSignature(
            "checkAndExecTransactionFromModule(address,address,uint256,bytes,uint8,uint256)",
            sender,
            target,
            value,
            data,
            operation,
            nonce
        );
    }

    function getPartialUserOp(AccountInstance memory instance, bytes memory callData, bytes memory initCode)
        internal
        returns (UserOperation memory)
    {
        // Get Safe address
        address smartAccount = address(instance.account);

        // // Get Safe initCode if not deployed already
        // bytes memory initCode = isDeployed(smartAccount) ? bytes("") : safeInitCode(instance);

        // Get nonce from Entrypoint
        uint256 nonce = instance.entrypoint.getNonce(smartAccount, 0);

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
