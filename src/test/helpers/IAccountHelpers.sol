// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";

interface IAccountHelpers {
    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module
    )
        external
        view
        returns (bool);

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        external
        view
        returns (bool);

    function getInstallModuleData(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        external
        view
        returns (bytes memory);

    function getUninstallModuleData(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        external
        view
        returns (bytes memory);

    function configModuleUserOp(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData,
        function(address, uint256, address, bytes memory)
            external
            returns (bytes memory) fn,
        address txValidator
    )
        external
        returns (PackedUserOperation memory userOp, bytes32 userOpHash);

    function execUserOp(
        AccountInstance memory instance,
        bytes memory callData,
        address txValidator
    )
        external
        view
        returns (PackedUserOperation memory userOp, bytes32 userOpHash);
}
