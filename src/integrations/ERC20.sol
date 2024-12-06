// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

// Types
import { Execution } from "../accounts/erc7579/lib/ExecutionLib.sol";

// Dependencies
import { ERC7579Exec } from "./ERC7579Exec.sol";

library ERC20Integration {
    using ERC7579Exec for address;

    error SafeERC20TransferFailed();

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 amount
    )
        internal
        pure
        returns (Execution memory exec0, Execution memory exec1)
    {
        exec0 = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (spender, 0))
        });
        exec1 = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (spender, amount))
        });
    }

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

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        safeTransfer(token, msg.sender, to, amount);
    }

    function safeTransfer(IERC20 token, address account, address to, uint256 amount) internal {
        bytes memory ret = account.exec7579({
            to: address(token),
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (to, amount))
        });
        if (ret.length != 0) {
            bool success = abi.decode(ret, (bool));
            if (!success) revert SafeERC20TransferFailed();
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        safeTransferFrom(token, msg.sender, from, to, amount);
    }

    function safeTransferFrom(
        IERC20 token,
        address account,
        address from,
        address to,
        uint256 amount
    )
        internal
    {
        bytes memory ret = account.exec7579({
            to: address(token),
            value: 0,
            data: abi.encodeCall(IERC20.transferFrom, (from, to, amount))
        });

        bytes[] memory retValues = abi.decode(ret, (bytes[]));
        if (retValues[0].length != 0) {
            bool success = abi.decode(retValues[0], (bool));
            if (!success) revert SafeERC20TransferFailed();
        }
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
