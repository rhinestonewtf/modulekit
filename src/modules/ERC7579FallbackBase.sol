// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Fallback } from "../external/ERC7579.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";

abstract contract ERC7579FallbackBase is IERC7579Fallback, ERC7579ModuleBase { }
