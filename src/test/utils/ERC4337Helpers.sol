// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { UserOperation, IEntryPoint } from "../../external/ERC4337.sol";
/* solhint-disable no-global-import */
import "./Vm.sol";
import "./Log.sol";

library ERC4337Helpers {
    function exec4337(
        address account,
        IEntryPoint entrypoint,
        UserOperation[] memory userOps
    )
        internal
    {
        recordLogs();
        entrypoint.handleOps(userOps, payable(address(0x69)));

        VmSafe.Log[] memory logs = getRecordedLogs();

        for (uint256 i; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == 0x1c4fada7374c0a9ee8841fc38afe82932dc0f8e69012e927f061a8bae611a201
            ) {
                if (getExpectRevert() != 1) revert("UserOperation failed");
            }
        }

        writeExpectRevert(0);

        for (uint256 i; i < userOps.length; i++) {
            emit ModuleKitLogs.ModuleKit_Exec4337(account, userOps[i].sender);
        }
    }

    function exec4337(
        address account,
        IEntryPoint entrypoint,
        UserOperation memory userOp
    )
        internal
    {
        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;
        exec4337(account, entrypoint, userOps);
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
