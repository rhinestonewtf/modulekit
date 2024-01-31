// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookBase } from "./ERC7579HookBase.sol";
import { IERC7579Account } from "../Accounts.sol";
import { ExecutionLib, Execution } from "umsa/lib/ExecutionLib.sol";
import {
    ModeLib,
    CallType,
    ModeCode,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL
} from "umsa/lib/ModeLib.sol";

abstract contract ERC7579HookDestruct is ERC7579HookBase {
    error HookInvalidSelector();

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        override
        returns (bytes memory hookData)
    {
        bytes4 selector = bytes4(msgData[0:4]);

        if (selector == IERC7579Account.execute.selector) {
            ModeCode mode = ModeCode.wrap(bytes32(msgData[4:36]));
            CallType calltype = ModeLib.getCallType(mode);
            if (calltype == CALLTYPE_SINGLE) {
                (address to, uint256 value, bytes calldata callData) =
                    ExecutionLib.decodeSingle(msgData[36:]);
                return onExecute(msgSender, to, value, callData);
            } else if (calltype == CALLTYPE_BATCH) {
                Execution[] calldata execs = ExecutionLib.decodeBatch(msgData[36:]);
                return onExecuteBatch(msgSender, execs);
            } else {
                revert HookInvalidSelector();
            }
        } else if (selector == IERC7579Account.executeFromExecutor.selector) {
            ModeCode mode = ModeCode.wrap(bytes32(msgData[4:36]));
            CallType calltype = ModeLib.getCallType(mode);
            if (calltype == CALLTYPE_SINGLE) {
                (address to, uint256 value, bytes calldata callData) =
                    ExecutionLib.decodeSingle(msgData[36:]);
                return onExecuteFromExecutor(msgSender, to, value, callData);
            } else if (calltype == CALLTYPE_BATCH) {
                Execution[] calldata execs = ExecutionLib.decodeBatch(msgData[36:]);
                return onExecuteBatchFromExecutor(msgSender, execs);
            } else {
                revert HookInvalidSelector();
            }
        } else if (selector == IERC7579Account.installModule.selector) {
            uint256 moduleType = uint256(bytes32(msgData[4:24]));
            address module = address(bytes20(msgData[24:36]));
            bytes calldata initData = msgData[36:];
            onInstallModule(msgSender, moduleType, module, initData);
        } else if (selector == IERC7579Account.uninstallModule.selector) {
            uint256 moduleType = uint256(bytes32(msgData[4:24]));
            address module = address(bytes20(msgData[24:36]));
            bytes calldata initData = msgData[36:];
            onUninstallModule(msgSender, moduleType, module, initData);
        } else {
            revert HookInvalidSelector();
        }
    }

    function postCheck(bytes calldata hookData) external override returns (bool success) {
        if (hookData.length == 0) return true;
        return onPostCheck(hookData);
    }

    function onPostCheck(bytes calldata hookData) internal virtual returns (bool success);
    /////////////////////////////////////////////////////
    // Executions
    ////////////////////////////////////////////////////
    function onExecute(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onExecuteBatch(
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onExecuteFromExecutor(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onExecuteBatchFromExecutor(
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        returns (bytes memory hookData);

    /////////////////////////////////////////////////////
    // IAccountConfig
    ////////////////////////////////////////////////////

    function onInstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onUninstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        internal
        virtual
        returns (bytes memory hookData);
}
