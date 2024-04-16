// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { DelegateCallTarget as DCTarget, EventEmitter } from "../utils/DelegatecallTarget.sol";
import { ISafe, ExecOnSafeLib } from "../lib/ExecOnSafeLib.sol";

contract DelegateCallUtil {
    using ExecOnSafeLib for ISafe;

    DCTarget internal DCTARGET;

    constructor() {
        DCTARGET = new DCTarget();
    }

    function _emitModuleInstall(uint256 moduleTypeId, address module) internal {
        ISafe(msg.sender).execDelegateCall({
            target: address(DCTARGET),
            callData: abi.encodeCall(EventEmitter.emitModuleInstalled, (moduleTypeId, module))
        });
    }

    function _emitModuleUninstall(uint256 moduleTypeId, address module) internal {
        ISafe(msg.sender).execDelegateCall({
            target: address(DCTARGET),
            callData: abi.encodeCall(EventEmitter.emitModuleUninstalled, (moduleTypeId, module))
        });
    }
}
