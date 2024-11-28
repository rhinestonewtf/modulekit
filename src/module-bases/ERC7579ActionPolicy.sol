// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { ERC7579PolicyBase } from "./ERC7579PolicyBase.sol";
import { ConfigId, IActionPolicy } from "./interfaces/IPolicy.sol";

abstract contract ERC7579ActionPolicy is ERC7579PolicyBase, IActionPolicy {
    function checkAction(
        ConfigId id,
        address account,
        address target,
        uint256 value,
        bytes calldata data
    )
        external
        virtual
        returns (uint256);
}
