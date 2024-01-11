// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC7579Execution } from "../Accounts.sol";

library ERC721Integration {
    function approve(
        IERC721 token,
        address spender,
        uint256 tokenId
    )
        internal
        pure
        returns (IERC7579Execution.Execution memory exec)
    {
        exec = IERC7579Execution.Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC721.approve, (spender, tokenId))
        });
    }

    function transferFrom(
        IERC721 token,
        address from,
        address to,
        uint256 tokenId
    )
        internal
        pure
        returns (IERC7579Execution.Execution memory exec)
    {
        exec = IERC7579Execution.Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC721.transferFrom, (from, to, tokenId))
        });
    }
}
