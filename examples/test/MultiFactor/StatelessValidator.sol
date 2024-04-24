// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.25;

import { IStatelessValidator } from "modulekit/src/interfaces/IStatelessValidator.sol";
import "modulekit/src/Modules.sol";
import "modulekit/src/ModuleKit.sol";
import "modulekit/src/Mocks.sol";

contract DemoValidator is MockValidator, IStatelessValidator {
    mapping(address account => bool isInitialized) public initialized;

    error AlreadyInstalled();

    function onInstall(bytes calldata data) external override {
        if (data.length == 0) revert("empty data");
        initialized[msg.sender] = true;
    }

    function onUninstall(bytes calldata data) external override {
        if (data.length == 0) revert("empty data");
        initialized[msg.sender] = false;
    }

    function validateSignatureWithData(
        bytes32 hash,
        bytes calldata signature,
        bytes calldata data
    )
        external
        view
        override
        returns (bool)
    {
        return true;
    }
}
