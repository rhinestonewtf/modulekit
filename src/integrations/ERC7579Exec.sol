// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

// Libraries
import {
    Execution,
    ExecutionLib as ERC7579ExecutionLib
} from "../accounts/erc7579/lib/ExecutionLib.sol";
import {
    ModeLib as ERC7579ModeLib,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    EXECTYPE_DEFAULT,
    CALLTYPE_DELEGATECALL,
    MODE_DEFAULT,
    ModePayload,
    ModeCode
} from "../accounts/common/lib/ModeLib.sol";

// Interfaces
import { IERC7579Account } from "../accounts/common/interfaces/IERC7579Account.sol";

library ERC7579Exec {
    function exec7579(
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

    function exec7579(
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        returns (bytes memory result)
    {
        return exec7579(msg.sender, to, value, data);
    }

    function exec7579(
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

    function exec7579(Execution[] memory execs) internal returns (bytes[] memory results) {
        return exec7579(msg.sender, execs);
    }

    // Note: Not every account will support delegatecalls
    function exec7579(
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
    function exec7579(
        address delegateTarget,
        bytes memory callData
    )
        internal
        returns (bytes[] memory results)
    {
        return exec7579(msg.sender, delegateTarget, callData);
    }
}
