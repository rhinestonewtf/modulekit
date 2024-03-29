// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookBase } from "../Modules.sol";

contract MockHook is ERC7579HookBase {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function preCheck(
        address msgSender,
        bytes calldata msgData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function postCheck(bytes calldata) external virtual override returns (bool success) {
        return true;
    }

    function isInitialized(address smartAccount) external pure returns (bool) {
        return false;
    }

    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_HOOK;
    }
}
