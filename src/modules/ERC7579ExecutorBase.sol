// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7579Executor } from "../external/ERC7579.sol";
import "./ERC7579ModuleBase.sol";

abstract contract ERC7579ExecutorBase is IERC7579Executor, ERC7579ModuleBase { }
