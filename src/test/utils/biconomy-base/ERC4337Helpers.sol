// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { RhinestoneAccount } from "./RhinestoneModuleKit.sol";
import { UserOperation } from "../../../common/erc4337/UserOperation.sol";

library ERC4337Wrappers {
    function getBiconomy4337TxCalldata(
        RhinestoneAccount memory instance,
        address target,
        uint256 value,
        bytes memory data
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSignature("execute(address,uint256,bytes)", target, value, data);
    }

    function getPartialUserOp(
        RhinestoneAccount memory instance,
        bytes memory callData,
        bytes memory initCode
    )
        internal
        returns (UserOperation memory)
    {
        // Get account address
        address smartAccount = address(instance.account);

        // Get nonce from Entrypoint
        uint256 nonce = instance.aux.entrypoint.getNonce(smartAccount, 0);

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
