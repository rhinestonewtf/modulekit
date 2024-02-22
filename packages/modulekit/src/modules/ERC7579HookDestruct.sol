// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

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
            uint256 paramLen = uint256(bytes32(msgData[INSTALL_OFFSET - 32:INSTALL_OFFSET]));
            bytes calldata initData = msgData[INSTALL_OFFSET:INSTALL_OFFSET + paramLen];
            uint256 moduleType = uint256(bytes32(msgData[4:36]));
            address module = address(bytes20((msgData[48:68])));
            return onInstallModule(msgSender, moduleType, module, initData);
        } else if (selector == IERC7579Account.uninstallModule.selector) {
            uint256 paramLen = uint256(bytes32(msgData[INSTALL_OFFSET - 32:INSTALL_OFFSET]));
            bytes calldata initData = msgData[INSTALL_OFFSET:INSTALL_OFFSET + paramLen];
            uint256 moduleType = uint256(bytes32(msgData[4:36]));
            address module = address(bytes20((msgData[48:68])));

            return onUninstallModule(msgSender, moduleType, module, initData);
        } else {
            revert();
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

    // if (selector == IERC7579Account.execute.selector) {
    //     ModeCode mode = ModeCode.wrap(bytes32(msgData[4:36]));
    //     CallType calltype = ModeLib.getCallType(mode);
    //     uint256 offset = msgData.offset();
    //     if (calltype == CALLTYPE_SINGLE) {
    //         (address to, uint256 value, bytes calldata callData) =
    //             ExecutionLib.decodeSingle(msgData[36:offset]);
    //         return onExecute(msgSender, to, value, callData);
    //     } else if (calltype == CALLTYPE_BATCH) {
    //         Execution[] calldata execs = ExecutionLib.decodeBatch(msgData[36:offset]);
    //         return onExecuteBatch(msgSender, execs);
    //     } else {
    //         revert HookInvalidSelector();
    //     }
    // } else if (selector == IERC7579Account.executeFromExecutor.selector) {
    //     uint256 offset = msgData.offset();
    //     console2.log("\n\n offset %s msgData.length %s", offset, msgData.length);
    //     console2.log("\nmsgData:");
    //     console2.logBytes(msgData);
    //     console2.log("\nmsgData cleaned:");
    //     console2.logBytes(msgData[36:offset]);
    //
    //     ModeCode mode = ModeCode.wrap(bytes32(msgData[4:36]));
    //     CallType calltype = ModeLib.getCallType(mode);
    //     if (calltype == CALLTYPE_SINGLE) {
    //         (address to, uint256 value, bytes calldata callData) =
    //             ExecutionLib.decodeSingle(msgData[36:offset]);
    //         return onExecuteFromExecutor(msgSender, to, value, callData);
    //     } else if (calltype == CALLTYPE_BATCH) {
    //         Execution[] calldata execs = ExecutionLib.decodeBatch(msgData[36:offset]);
    //         return onExecuteBatchFromExecutor(msgSender, execs);
    //     } else {
    //         revert HookInvalidSelector();
    //     }
    // } else if (selector == IERC7579Account.installModule.selector) {
    //     uint256 offset = msgData.offset();
    //     uint256 moduleType = uint256(bytes32(msgData[4:24]));
    //     address module = address(bytes20(msgData[24:36]));
    //     bytes calldata initData = msgData[36:offset];
    //     onInstallModule(msgSender, moduleType, module, initData);
    // } else if (selector == IERC7579Account.uninstallModule.selector) {
    //     uint256 offset = msgData.offset();
    //     uint256 moduleType = uint256(bytes32(msgData[4:24]));
    //     address module = address(bytes20(msgData[24:36]));
    //     bytes calldata initData = msgData[36:offset];
    //     onUninstallModule(msgSender, moduleType, module, initData);
    // } else {
    //     revert HookInvalidSelector();
    // }

    function postCheck(bytes calldata hookData) external override returns (bool success) {
        if (hookData.length == 0) return true;
        return onPostCheck(hookData);
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

    /*//////////////////////////////////////////////////////////////////////////
                                     POSTCHECK
    //////////////////////////////////////////////////////////////////////////*/

    function onPostCheck(bytes calldata hookData) internal virtual returns (bool success);
}
