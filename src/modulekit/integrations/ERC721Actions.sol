// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.18;

import "forge-std/interfaces/IERC721.sol";
import "../interfaces/IExecutor.sol";
import "./interfaces/IWETH.sol";

library ERC721ModuleKit {
    function transferFromAction(
        IERC721 token,
        address from,
        address to,
        uint256 tokenId
    )
        internal
        pure
        returns (ExecutorAction memory action)
    {
        action = ExecutorAction({
            to: payable(address(token)),
            value: 0,
            data: abi.encodeCall(IERC721.transferFrom, (from, to, tokenId))
        });
    }
}
