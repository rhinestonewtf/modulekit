// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";
import { ISessionValidationModule } from
    "@rhinestone/sessionkeymanager/src/ISessionValidationModule.sol";

abstract contract SessionKeyBase is ISessionValidationModule, ERC7579ModuleBase {
    error InvalidMethod(bytes4);
    error InvalidValue();
    error InvalidAmount();
    error InvalidTarget();
    error InvalidRecipient();

    modifier onlyThis(address destinationContract) {
        if (destinationContract != address(this)) revert InvalidTarget();
        _;
    }

    modifier onlyFunctionSig(bytes4 allowed, bytes4 received) {
        if (allowed != received) revert InvalidMethod(received);
        _;
    }

    modifier onlyZeroValue(uint256 callValue) {
        if (callValue != 0) revert InvalidValue();
        _;
    }
}
