// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579HookBase } from "./ERC7579HookBase.sol";
import { IERC7579Account } from "../Accounts.sol";
import { ExecutionLib, Execution } from "erc7579/lib/ExecutionLib.sol";
import {
    ModeLib,
    CallType,
    ModeCode,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL
} from "erc7579/lib/ModeLib.sol";

uint256 constant EXEC_OFFSET = 100;
uint256 constant INSTALL_OFFSET = 132;

abstract contract ERC7579HookDestruct is ERC7579HookBase {
    error HookInvalidSelector();

    /*//////////////////////////////////////////////////////////////////////////
                                CALLDATA DECODING
    //////////////////////////////////////////////////////////////////////////*/

    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    {
        bytes4 selector = bytes4(msgData[0:4]);

        if (selector == IERC7579Account.execute.selector) {
            return _handle4337Executions(msgSender, msgData);
        } else if (selector == IERC7579Account.executeFromExecutor.selector) {
            return _handleExecutorExecutions(msgSender, msgData);
        } else if (selector == IERC7579Account.installModule.selector) {
            uint256 paramLen = msgData.length > INSTALL_OFFSET
                ? uint256(bytes32(msgData[INSTALL_OFFSET - 32:INSTALL_OFFSET]))
                : uint256(0);
            bytes calldata initData = msgData.length > INSTALL_OFFSET
                ? msgData[INSTALL_OFFSET:INSTALL_OFFSET + paramLen]
                : msgData[0:0];
            uint256 moduleType = uint256(bytes32(msgData[4:36]));
            address module = address(bytes20((msgData[48:68])));
            return onInstallModule(msgSender, moduleType, module, initData);
        } else if (selector == IERC7579Account.uninstallModule.selector) {
            uint256 paramLen = msgData.length > INSTALL_OFFSET
                ? uint256(bytes32(msgData[INSTALL_OFFSET - 32:INSTALL_OFFSET]))
                : uint256(0);
            bytes calldata initData = msgData.length > INSTALL_OFFSET
                ? msgData[INSTALL_OFFSET:INSTALL_OFFSET + paramLen]
                : msgData[0:0];

            uint256 moduleType = uint256(bytes32(msgData[4:36]));
            address module = address(bytes20((msgData[48:68])));

            return onUninstallModule(msgSender, moduleType, module, initData);
        } else {
            return onUnknownFunction(msgSender, msgValue, msgData);
        }
    }

    function _handle4337Executions(
        address msgSender,
        bytes calldata msgData
    )
        internal
        returns (bytes memory hookData)
    {
        uint256 paramLen = uint256(bytes32(msgData[EXEC_OFFSET - 32:EXEC_OFFSET]));
        bytes calldata encodedExecutions = msgData[EXEC_OFFSET:EXEC_OFFSET + paramLen];

        ModeCode mode = ModeCode.wrap(bytes32(msgData[4:36]));
        CallType calltype = ModeLib.getCallType(mode);

        if (calltype == CALLTYPE_SINGLE) {
            (address to, uint256 value, bytes calldata callData) =
                ExecutionLib.decodeSingle(encodedExecutions);
            return onExecute(msgSender, to, value, callData);
        } else if (calltype == CALLTYPE_BATCH) {
            Execution[] calldata execs = ExecutionLib.decodeBatch(encodedExecutions);
            return onExecuteBatch(msgSender, execs);
        }
    }

    function _handleExecutorExecutions(
        address msgSender,
        bytes calldata msgData
    )
        internal
        returns (bytes memory hookData)
    {
        uint256 paramLen = uint256(bytes32(msgData[EXEC_OFFSET - 32:EXEC_OFFSET]));
        bytes calldata encodedExecutions = msgData[EXEC_OFFSET:EXEC_OFFSET + paramLen];

        ModeCode mode = ModeCode.wrap(bytes32(msgData[4:36]));
        CallType calltype = ModeLib.getCallType(mode);

        if (calltype == CALLTYPE_SINGLE) {
            (address to, uint256 value, bytes calldata callData) =
                ExecutionLib.decodeSingle(encodedExecutions);
            return onExecuteFromExecutor(msgSender, to, value, callData);
        } else if (calltype == CALLTYPE_BATCH) {
            Execution[] calldata execs = ExecutionLib.decodeBatch(encodedExecutions);
            return onExecuteBatchFromExecutor(msgSender, execs);
        }
    }

    function postCheck(
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        external
        override
    {
        onPostCheck(hookData, executionSuccess, executionReturnValue);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     EXECUTION
    //////////////////////////////////////////////////////////////////////////*/

    function onExecute(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    function onExecuteBatch(
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    function onExecuteFromExecutor(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    function onExecuteBatchFromExecutor(
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    function onUninstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    /*//////////////////////////////////////////////////////////////////////////
                                UNKNOWN FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function onUnknownFunction(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    /*//////////////////////////////////////////////////////////////////////////
                                     POSTCHECK
    //////////////////////////////////////////////////////////////////////////*/

    function onPostCheck(
        bytes calldata hookData,
        bool executionSuccess,
        bytes calldata executionReturnValue
    )
        internal
        virtual
    { }
}
