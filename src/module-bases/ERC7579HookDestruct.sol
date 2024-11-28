// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { IERC7579Account } from "../accounts/common/interfaces/IERC7579Account.sol";
import { IHook as IERC7579Hook } from "../accounts/common/interfaces/IERC7579Module.sol";
import { ExecutionLib, Execution } from "../accounts/erc7579/lib/ExecutionLib.sol";
import {
    ModeLib,
    CallType,
    ModeCode,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL
} from "../accounts/common/lib/ModeLib.sol";
import { IAccountExecute } from "../external/ERC4337.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";
import { TrustedForwarder } from "./utils/TrustedForwarder.sol";

uint256 constant EXECUSEROP_OFFSET = 164;
uint256 constant EXEC_OFFSET = 100;
uint256 constant INSTALL_OFFSET = 132;

abstract contract ERC7579HookDestruct is IERC7579Hook, ERC7579ModuleBase, TrustedForwarder {
    error HookInvalidSelector();
    error InvalidCallType();

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

        if (selector == IAccountExecute.executeUserOp.selector) {
            uint256 offset =
                uint256(bytes32(msgData[EXECUSEROP_OFFSET:EXECUSEROP_OFFSET + 32])) + 68;
            uint256 paramLen = uint256(bytes32(msgData[offset:offset + 32]));
            offset += 32;
            bytes calldata _msgData = msgData[offset:offset + paramLen];
            return _decodeCallData(msgSender, msgValue, _msgData);
        } else {
            return _decodeCallData(msgSender, msgValue, msgData);
        }
    }

    function _decodeCallData(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
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
            return onInstallModule(_getAccount(), msgSender, moduleType, module, initData);
        } else if (selector == IERC7579Account.uninstallModule.selector) {
            uint256 paramLen = msgData.length > INSTALL_OFFSET
                ? uint256(bytes32(msgData[INSTALL_OFFSET - 32:INSTALL_OFFSET]))
                : uint256(0);
            bytes calldata initData = msgData.length > INSTALL_OFFSET
                ? msgData[INSTALL_OFFSET:INSTALL_OFFSET + paramLen]
                : msgData[0:0];

            uint256 moduleType = uint256(bytes32(msgData[4:36]));
            address module = address(bytes20((msgData[48:68])));

            return onUninstallModule(_getAccount(), msgSender, moduleType, module, initData);
        } else {
            return onUnknownFunction(_getAccount(), msgSender, msgValue, msgData);
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
            return onExecute(_getAccount(), msgSender, to, value, callData);
        } else if (calltype == CALLTYPE_BATCH) {
            Execution[] calldata execs = ExecutionLib.decodeBatch(encodedExecutions);
            return onExecuteBatch(_getAccount(), msgSender, execs);
        } else if (calltype == CALLTYPE_DELEGATECALL) {
            address to = address(bytes20(encodedExecutions[0:20]));
            bytes calldata callData = encodedExecutions[20:];
            return onExecuteDelegateCall(_getAccount(), msgSender, to, callData);
        } else {
            revert InvalidCallType();
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
            return onExecuteFromExecutor(_getAccount(), msgSender, to, value, callData);
        } else if (calltype == CALLTYPE_BATCH) {
            Execution[] calldata execs = ExecutionLib.decodeBatch(encodedExecutions);
            return onExecuteBatchFromExecutor(_getAccount(), msgSender, execs);
        } else if (calltype == CALLTYPE_DELEGATECALL) {
            address to = address(bytes20(encodedExecutions[0:20]));
            bytes calldata callData = encodedExecutions[20:];
            return onExecuteDelegateCallFromExecutor(_getAccount(), msgSender, to, callData);
        } else {
            revert InvalidCallType();
        }
    }

    function postCheck(bytes calldata hookData) external virtual override {
        onPostCheck(_getAccount(), hookData);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     EXECUTION
    //////////////////////////////////////////////////////////////////////////*/

    function onExecute(
        address account,
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
        address account,
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    function onExecuteDelegateCall(
        address account,
        address msgSender,
        address target,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    function onExecuteFromExecutor(
        address account,
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
        address account,
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    function onExecuteDelegateCallFromExecutor(
        address account,
        address msgSender,
        address target,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData)
    { }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstallModule(
        address account,
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
        address account,
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
        address account,
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

    function onPostCheck(address account, bytes calldata hookData) internal virtual { }
}
