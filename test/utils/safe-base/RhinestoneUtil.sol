// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {AccountInstance} from "./AccountFactory.sol";

library RhinestoneUtil {
    function exec4337(
        AccountInstance memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        uint8 operation, // {0: Call, 1: DelegateCall}
        bytes memory signature
    ) internal {
        bytes memory data = ERC4337Wrappers.getSafe4337TxCalldata(instance, target, value, callData, operation);

        if (signature.length == 0) {
            // TODO: generate default signature
            signature = bytes("");
        }
        exec4337(instance, data);
    }

    function exec4337(AccountInstance memory instance, bytes memory callData) internal returns (bool, bytes memory) {
        // prepare ERC4337 UserOperation

        bytes memory initCode = isDeployed(instance) ? bytes("") : SafeHelpers.safeInitCode(instance);
        UserOperation memory userOp = ERC4337Wrappers.getPartialUserOp(instance, callData, initCode);
        // mock signature
        userOp.signature = bytes("");

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        // send userOps to 4337 entrypoint
        instance.entrypoint.handleOps(userOps, payable(address(0x69)));
    }

    function addValidator(AccountInstance memory instance, address validator) internal returns (bool) {}

    function addRecovery(AccountInstance memory instance, address recovery) internal returns (bool) {}

    function addPlugin(AccountInstance memory instance, address plugin) internal returns (bool) {}

    function isDeployed(AccountInstance memory instance) internal view returns (bool) {
        address _addr = address(instance.account);
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
