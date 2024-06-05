// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccountInstance } from "../RhinestoneModuleKit.sol";

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
}
