// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { IExecutor as IERC7579Executor } from "../accounts/common/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "../accounts/common/interfaces/IERC7579Account.sol";
import {
    Execution,
    ExecutionLib as ERC7579ExecutionLib
} from "../accounts/erc7579/lib/ExecutionLib.sol";
import {
    ModeCode,
    ModeLib as ERC7579ModeLib,
    CALLTYPE_SINGLE,
    EXECTYPE_DEFAULT,
    MODE_DEFAULT,
    ModePayload,
    CALLTYPE_BATCH,
    EXECTYPE_DEFAULT,
    MODE_DEFAULT,
    CALLTYPE_DELEGATECALL
} from "../accounts/common/lib/ModeLib.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";

abstract contract ERC7579ExecutorBase is IERC7579Executor, ERC7579ModuleBase {
    function _execute(
        address account,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bytes memory result)
    {
        ModeCode modeCode = ERC7579ModeLib.encode({
            callType: CALLTYPE_SINGLE,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });

        return IERC7579Account(account).executeFromExecutor(
            modeCode, ERC7579ExecutionLib.encodeSingle(to, value, data)
        )[0];
    }

    function _execute(
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bytes memory result)
    {
        return _execute(msg.sender, to, value, data);
    }

    function _execute(
        address account,
        Execution[] memory execs
    )
        internal
        returns (bytes[] memory results)
    {
        ModeCode modeCode = ERC7579ModeLib.encode({
            callType: CALLTYPE_BATCH,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });
        results = IERC7579Account(account).executeFromExecutor(
            modeCode, ERC7579ExecutionLib.encodeBatch(execs)
        );
    }

    function _execute(Execution[] memory execs) internal returns (bytes[] memory results) {
        return _execute(msg.sender, execs);
    }

    // Note: Not every account will support delegatecalls
    function _executeDelegateCall(
        address account,
        address delegateTarget,
        bytes memory callData
    )
        internal
        returns (bytes[] memory results)
    {
        ModeCode modeCode = ERC7579ModeLib.encode({
            callType: CALLTYPE_DELEGATECALL,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });
        results = IERC7579Account(account).executeFromExecutor(
            modeCode, abi.encodePacked(delegateTarget, callData)
        );
    }

    // Note: Not every account will support delegatecalls
    function _executeDelegateCall(
        address delegateTarget,
        bytes memory callData
    )
        internal
        returns (bytes[] memory results)
    {
        return _executeDelegateCall(msg.sender, delegateTarget, callData);
    }
}
