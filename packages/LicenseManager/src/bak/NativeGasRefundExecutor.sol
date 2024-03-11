// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "account-abstraction/interfaces/IEntryPoint.sol";
import { IERC7579Account, Execution } from "@rhinestone/modulekit/src/external/ERC7579.sol";
import {
    CallType, ModeCode, ModeLib, CALLTYPE_SINGLE, CALLTYPE_BATCH
} from "erc7579/lib/ModeLib.sol";
import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";

import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";

abstract contract NativeGasRefundExecutor {
    using ModeLib for ModeCode;
    using ExecutionLib for bytes;
    using SafeTransferLib for address;

    IEntryPoint immutable ENTRYPOINT;

    constructor(IEntryPoint _entrypoint) {
        ENTRYPOINT = _entrypoint;
    }

    function onInstall(bytes calldata data) external { }

    function onUninstall(bytes calldata data) external { }

    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == 2;
    }

    function isInitialized(address smartAccount) external view returns (bool) { }

    function _gasRefundNative(address smartAccount, uint256 requiredPreFund) internal {
        IERC7579Account(smartAccount).executeFromExecutor(
            ModeCode.wrap(0),
            ExecutionLib.encodeSingle({ target: address(this), value: requiredPreFund, callData: "" })
        );
    }

    function _returnUnneededGas(address smartAccount, uint256 amount) internal {
        payable(smartAccount).transfer(amount);
    }
}
