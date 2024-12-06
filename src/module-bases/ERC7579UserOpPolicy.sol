// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { ERC7579PolicyBase } from "./ERC7579PolicyBase.sol";
import { ConfigId, IUserOpPolicy } from "./interfaces/IPolicy.sol";
import { PackedUserOperation } from "../external/ERC4337.sol";

abstract contract ERC7579UserOpPolicy is ERC7579PolicyBase, IUserOpPolicy {
    function checkUserOp(
        ConfigId id,
        PackedUserOperation calldata userOp
    )
        external
        virtual
        returns (uint256);
}
