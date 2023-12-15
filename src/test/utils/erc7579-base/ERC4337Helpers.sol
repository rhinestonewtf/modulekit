// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { RhinestoneAccount } from "./RhinestoneModuleKit.sol";
import { UserOperation } from "../../../common/erc4337/UserOperation.sol";

import { IExecution } from "erc7579/interfaces/IMSA.sol";

library ERC4337Wrappers {
    function getERC7579TxCalldata(
        RhinestoneAccount memory account,
        address target,
        uint256 value,
        bytes memory data
    )
        internal
        view
        returns (bytes memory erc7579Tx)
    {
        return abi.encodeCall(IExecution.execute, (target, value, data));
    }
}
