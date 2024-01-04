// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookBase } from "./ERC7579HookBase.sol";
import { IERC7579Execution } from "../ModuleKitLib.sol";

import { IERC7579Config, IERC7579ConfigHook } from "../external/ERC7579.sol";

abstract contract ERC7579HookDeconstructor is ERC7579HookBase {
    error HookInvalidSelector(bytes4);

    function preCheck(
        address msgSender,
        bytes calldata msgData
    )
        external
        override
        returns (bytes memory hookData)
    {
        bytes4 accountExecSelector = bytes4(msgData[0:4]);
        if (IERC7579Execution.execute.selector == accountExecSelector) {
            address to = address(bytes20(msgData[16:36]));
            uint256 value = uint256(bytes32(msgData[36:68]));
            bytes calldata callData = msgData[132:msgData.length - 28];
            return onExecute(msgSender, to, value, callData);
        }

        if (IERC7579Execution.executeBatch.selector == accountExecSelector) {
            bytes calldata _executions = msgData[4:];
            IERC7579Execution.Execution[] memory executions =
                abi.decode(_executions, (IERC7579Execution.Execution[]));

            return onExecuteBatchFromModule(msgSender, executions);
        }

        if (IERC7579Execution.executeFromExecutor.selector == accountExecSelector) {
            address to = address(bytes20(msgData[16:36]));
            uint256 value = uint256(bytes32(msgData[36:68]));
            bytes calldata callData = msgData[132:];
            return onExecuteFromModule(msgSender, to, value, callData);
        }

        if (IERC7579Execution.executeBatchFromExecutor.selector == accountExecSelector) {
            bytes calldata _executions = msgData[4:];
            IERC7579Execution.Execution[] memory executions =
                abi.decode(_executions, (IERC7579Execution.Execution[]));

            return onExecuteBatchFromModule(msgSender, executions);
        }

        if (IERC7579ConfigHook.uninstallHook.selector == accountExecSelector) {
            address hook = address(bytes20(msgData[4:24]));
            bytes calldata data = msgData[24:];
            // always allow removal of this hook. Avoid dev error
            if (hook == address(this)) {
                return "";
            } else {
                return onDisableHook(msgSender, hook, data);
            }
        }
        if (IERC7579Config.installValidator.selector == accountExecSelector) {
            address validator = address(bytes20(msgData[4:24]));
            bytes calldata data = msgData[24:];
            return onEnableValidator(msgSender, validator, data);
        }

        if (IERC7579Config.installExecutor.selector == accountExecSelector) {
            address executor = address(bytes20(msgData[4:24]));
            bytes calldata data = msgData[24:];
            return onEnableExecutor(msgSender, executor, data);
        }

        revert HookInvalidSelector(accountExecSelector);
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
        IERC7579Execution.Execution[] calldata
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onExecuteFromModule(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onExecuteBatchFromModule(
        address msgSender,
        IERC7579Execution.Execution[] memory
    )
        internal
        virtual
        returns (bytes memory hookData);

    /////////////////////////////////////////////////////
    // Unsafe Executions
    ////////////////////////////////////////////////////
    function onExecuteDelegateCall(
        address msgSender,
        address target,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onExecuteDelegateCallFromModule(
        address msgSender,
        address target,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    /////////////////////////////////////////////////////
    // IAccountConfig
    ////////////////////////////////////////////////////

    function onEnableExecutor(
        address msgSender,
        address executor,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onDisableExecutor(
        address msgSender,
        address executor,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onEnableValidator(
        address msgSender,
        address validator,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onDisableValidator(
        address msgSender,
        address validator,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    /////////////////////////////////////////////////////
    // IAccountConfig_Hook
    ////////////////////////////////////////////////////
    function onDisableHook(
        address msgSender,
        address hookModule,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onEnableHook(
        address msgSender,
        address hookModule,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);
}
