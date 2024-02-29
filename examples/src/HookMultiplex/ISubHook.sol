// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";

interface ISubHook {
    function onExecute(
        address smartAccount,
        address module,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        returns (bytes memory hookData);

    function onExecuteBatch(
        address smartAccount,
        address module,
        Execution[] calldata executions
    )
        external
        returns (bytes memory hookData);

    function onExecuteFromExecutor(
        address smartAccount,
        address module,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        returns (bytes memory hookData);

    function onExecuteBatchFromExecutor(
        address smartAccount,
        address module,
        Execution[] calldata executions
    )
        external
        returns (bytes memory hookData);

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstallModule(
        address smartAccount,
        address module,
        uint256 moduleType,
        address moduleToInstall,
        bytes calldata initData
    )
        external
        returns (bytes memory hookData);

    function onUninstallModule(
        address smartAccount,
        address module,
        uint256 moduleType,
        address moduleToUninstall,
        bytes calldata deInitData
    )
        external
        returns (bytes memory hookData);

    /*//////////////////////////////////////////////////////////////////////////
                                     POSTCHECK
    //////////////////////////////////////////////////////////////////////////*/

    function onPostCheck(bytes calldata hookData) external returns (bool success);
}
