// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookBase } from "./ERC7579HookBase.sol";
import { IERC7579Execution } from "../Accounts.sol";
import { IERC7579Config, IERC7579ConfigHook } from "../external/ERC7579.sol";
import { ACCOUNT_EXEC_TYPE, ERC7579ValidatorLib } from "./utils/ERC7579ValidatorLib.sol";

abstract contract ERC7579HookDeconstructor is ERC7579HookBase {
    error HookInvalidSelector();

    function preCheck(
        address msgSender,
        bytes calldata msgData
    )
        external
        override
        returns (bytes memory hookData)
    {
        ACCOUNT_EXEC_TYPE execType = ERC7579ValidatorLib.decodeExecType(msgData);

        if (execType == ACCOUNT_EXEC_TYPE.EXEC_SINGLE) {
            (address to, uint256 value, bytes calldata callData) =
                ERC7579ValidatorLib.decodeCalldataSingle(msgData);
            return onExecute(msgSender, to, value, callData);
        } else if (execType == ACCOUNT_EXEC_TYPE.EXEC_BATCH) {
            IERC7579Execution.Execution[] calldata execs =
                ERC7579ValidatorLib.decodeCalldataBatch(msgData);
            return onExecuteBatch(msgSender, execs);
        } else if (execType == ACCOUNT_EXEC_TYPE.EXEC_SINGLE_FROM_EXECUTOR) {
            (address to, uint256 value, bytes calldata callData) =
                ERC7579ValidatorLib.decodeCalldataSingle(msgData);
            return onExecuteFromExecutor(msgSender, to, value, callData);
        } else if (execType == ACCOUNT_EXEC_TYPE.EXEC_BATCH_FROM_EXECUTOR) {
            IERC7579Execution.Execution[] calldata execs =
                ERC7579ValidatorLib.decodeCalldataBatch(msgData);
            return onExecuteBatchFromExecutor(msgSender, execs);
        } else if (execType == ACCOUNT_EXEC_TYPE.INSTALL_VALIDATOR) {
            (address module, bytes calldata callData) = ERC7579ValidatorLib.decodeConfig(msgData);
            return onInstallValidator(msgSender, module, callData);
        } else if (execType == ACCOUNT_EXEC_TYPE.INSTALL_EXECUTOR) {
            (address module, bytes calldata callData) = ERC7579ValidatorLib.decodeConfig(msgData);
            return onInstallExecutor(msgSender, module, callData);
        } else if (execType == ACCOUNT_EXEC_TYPE.UNINSTALL_HOOK) {
            (address module, bytes calldata callData) = ERC7579ValidatorLib.decodeConfig(msgData);
            if (module == address(this)) return ""; // always allow uninstalling this hook
            return onUninstallHook(msgSender, module, callData);
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
        IERC7579Execution.Execution[] calldata
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
        IERC7579Execution.Execution[] calldata
    )
        internal
        virtual
        returns (bytes memory hookData);

    /////////////////////////////////////////////////////
    // IAccountConfig
    ////////////////////////////////////////////////////

    function onInstallExecutor(
        address msgSender,
        address executor,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onUninstallExecutor(
        address msgSender,
        address executor,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onInstallValidator(
        address msgSender,
        address validator,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onUninstallValidator(
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
    function onUninstallHook(
        address msgSender,
        address hookModule,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);

    function onInstallHook(
        address msgSender,
        address hookModule,
        bytes calldata callData
    )
        internal
        virtual
        returns (bytes memory hookData);
}
