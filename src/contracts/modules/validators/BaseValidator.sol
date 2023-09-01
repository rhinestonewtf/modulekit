// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IValidatorModule, UserOperation } from "./IValidatorModule.sol";
import { ISignatureValidator, ISignatureValidatorConstants } from "./ISignatureValidator.sol";

contract AuthorizationModulesConstants {
    uint256 internal constant VALIDATION_SUCCESS = 0;
    uint256 internal constant SIG_VALIDATION_FAILED = 1;
}

abstract contract BaseValidator is
    IValidatorModule,
    ISignatureValidator,
    AuthorizationModulesConstants
{ }
