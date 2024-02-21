// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IFallback, EncodedModuleTypes } from "erc7579/interfaces/IERC7579Module.sol";
import { IERC7579Account, Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { HandlerContext } from "@safe-global/safe-contracts/contracts/handler/HandlerContext.sol";

contract MockFallback is IFallback, HandlerContext {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function target(uint256 value)
        external
        returns (uint256 _value, address erc2771Sender, address msgSender)
    {
        _value = value;
        erc2771Sender = _msgSender();
        msgSender = msg.sender;
    }

    function isModuleType(uint256 typeID) external view returns (bool) {
        return typeID == 3;
    }

    function getModuleTypes() external view returns (EncodedModuleTypes) { }

    function isInitialized(address smartAccount) external view returns (bool) {
        return false;
    }
}
