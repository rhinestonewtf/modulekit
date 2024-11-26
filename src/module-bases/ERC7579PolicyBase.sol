// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { ERC7579ModuleBase } from "./ERC7579ModuleBase.sol";
import { IPolicy, ConfigId } from "./interfaces/IPolicy.sol";

abstract contract ERC7579PolicyBase is ERC7579ModuleBase, IPolicy {
    function initializeWithMultiplexer(
        address account,
        ConfigId configId,
        bytes calldata initData
    )
        external
        virtual;
}
