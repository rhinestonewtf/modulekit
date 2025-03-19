// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

/* solhint-disable no-unused-import */

/*//////////////////////////////////////////////////////////////
                              AUX
//////////////////////////////////////////////////////////////*/

import { MockRegistry } from "./module-bases/mocks/MockRegistry.sol";
import { MockTarget } from "./module-bases/mocks/MockTarget.sol";
import { MockHookMultiPlexer } from "./module-bases/mocks/MockHookMultiPlexer.sol";
import { MockPolicy } from "./module-bases/mocks/MockPolicy.sol";

/*//////////////////////////////////////////////////////////////
                            MODULES
//////////////////////////////////////////////////////////////*/

import { MockValidator } from "./module-bases/mocks/MockValidator.sol";
import { MockStatelessValidator } from "./module-bases/mocks/MockStatelessValidator.sol";
import { MockHybridValidator } from "./module-bases/mocks/MockHybridValidator.sol";
import { MockExecutor } from "./module-bases/mocks/MockExecutor.sol";
import { MockHook } from "./module-bases/mocks/MockHook.sol";
import { MockFallback } from "./module-bases/mocks/MockFallback.sol";

/*//////////////////////////////////////////////////////////////
                            TOKENS
//////////////////////////////////////////////////////////////*/

import { MockERC20 } from "forge-std/mocks/MockERC20.sol";
import { MockERC721 } from "forge-std/mocks/MockERC721.sol";
