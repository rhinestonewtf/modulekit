// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockERC721 } from "solmate/test/utils/mocks/MockERC721.sol";
import { MockCondition } from "./test/mocks/MockCondition.sol";
import { ERC1271Yes, ERC1271No } from "./test/mocks/MockERC1271.sol";
import { MockExecutor } from "./test/mocks/MockExecutor.sol";
import { MockHook } from "./test/mocks/MockHook.sol";
import { MockProtocol } from "./test/mocks/MockProtocol.sol";
import { MockRegistry } from "./test/mocks/MockRegistry.sol";
import { MockValidator } from "./test/mocks/MockValidator.sol";
import { DebugExecutorManager } from "./test/mocks/DebugExecutorManager.sol";
