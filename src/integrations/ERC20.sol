// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IERC7579Account, Execution } from "../Accounts.sol";

library ERC20Integration {
    function approve(
        IERC20 token,
        address spender,
        uint256 amount
    )
        internal
        pure
        returns (Execution memory exec)
    {
        exec = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (spender, amount))
        });
    }

    function transfer(
        IERC20 token,
        address to,
        uint256 amount
    )
        internal
        pure
        returns (Execution memory exec)
    {
        exec = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (to, amount))
        });
    }

    function transferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    )
        internal
        pure
        returns (Execution memory exec)
    {
        exec = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.transferFrom, (from, to, amount))
        });
    }
}
