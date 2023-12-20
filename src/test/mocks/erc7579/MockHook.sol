// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "erc7579/interfaces/IModule.sol";
import "erc7579/interfaces/IMSA.sol";

contract MockHook is IHook {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function preCheck(
        address msgSender,
        bytes calldata msgData
    )
        external
        override
        returns (bytes memory hookData)
    { }

    function postCheck(bytes calldata hookData) external override returns (bool success) {
        return true;
    }
}
