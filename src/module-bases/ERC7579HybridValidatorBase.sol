// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

/* solhint-disable no-unused-import */

import {
    PackedUserOperation,
    _packValidationData as _packValidationData4337
} from "../external/ERC4337.sol";
import { ERC7579ValidatorBase } from "./ERC7579ValidatorBase.sol";
import { ERC7579StatelessValidatorBase } from "./ERC7579StatelessValidatorBase.sol";

/// @notice Base contract for hybrid validators, which are both stateful and stateless.
abstract contract ERC7579HybridValidatorBase is
    ERC7579ValidatorBase,
    ERC7579StatelessValidatorBase
{ }
