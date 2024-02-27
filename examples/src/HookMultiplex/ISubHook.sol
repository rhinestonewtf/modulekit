// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";

interface ISubHook {
    function onExecute(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        returns (bytes memory hookData);

    function onExecuteBatch(
        address msgSender,
        Execution[] calldata
    )
        external
        returns (bytes memory hookData);

    function onExecuteFromExecutor(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        returns (bytes memory hookData);

    function onExecuteBatchFromExecutor(
        address msgSender,
        Execution[] calldata
    )
        external
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
        external
        returns (bytes memory hookData);

    function onUninstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        external
        returns (bytes memory hookData);

    /*//////////////////////////////////////////////////////////////////////////
                                     POSTCHECK
    //////////////////////////////////////////////////////////////////////////*/

    function onPostCheck(bytes calldata hookData) external returns (bool success);
}
