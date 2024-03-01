pragma solidity ^0.8.0;

import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/modules/ERC7579ValidatorBase.sol";
import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";

interface IHookPolicy {
    function registerHookPolicy(
        address smartAccount,
        bytes32 permissionId,
        bytes calldata policyData
    )
        external
        payable;

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
