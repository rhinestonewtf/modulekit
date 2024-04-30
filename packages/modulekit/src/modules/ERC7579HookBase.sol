// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC7579Hook } from "../external/ERC7579.sol";
import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";

abstract contract ERC7579HookBase is IERC7579Hook, ERC7579ModuleBase { }
