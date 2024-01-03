// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookBase } from "../Modules.sol";
import { UserOperation } from "../external/ERC4337.sol";

contract MockHook is ERC7579HookBase {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_HOOK;
    }

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

    function name() external pure virtual override returns (string memory) {
        return "MockHook";
    }

    function version() external pure virtual override returns (string memory) {
        return "0.0.1";
    }
}
