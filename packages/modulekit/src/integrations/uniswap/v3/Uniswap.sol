// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SWAPROUTER_ADDRESS, SWAPROUTER_DEFAULTFEE } from "../helpers/MainnetAddresses.sol";
import { ISwapRouter } from "../../interfaces/uniswap/v3/ISwapRouter.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ERC20Integration } from "../../ERC20.sol";
import { IERC7579Account, Execution } from "../../../Accounts.sol";

/// @author zeroknots
library UniswapV3Integration {
    using ERC20Integration for IERC20;

    function approveAndSwap(
        address smartAccount,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    )
        internal
        view
        returns (Execution[] memory exec)
    {
        exec = new Execution[](2);
        exec[0] = ERC20Integration.approve(tokenIn, SWAPROUTER_ADDRESS, amountIn);
        exec[1] = swapExactInputSingle(smartAccount, tokenIn, tokenOut, amountIn, sqrtPriceLimitX96);
    }

    function swapExactInputSingle(
        address smartAccount,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    )
        internal
        view
        returns (Execution memory exec)
    {
        exec = Execution({
            target: SWAPROUTER_ADDRESS,
            value: 0,
            callData: abi.encodeCall(
                ISwapRouter.exactInputSingle,
                (
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: address(tokenIn),
                        tokenOut: address(tokenOut),
                        fee: SWAPROUTER_DEFAULTFEE,
                        recipient: smartAccount,
                        deadline: block.timestamp,
                        amountIn: amountIn,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: sqrtPriceLimitX96
                    })
                )
                )
        });
    }

    function swapExactOutputSingle(
        address smartAccount,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountOut,
        uint256 amountInMaximum
    )
        internal
        view
        returns (Execution memory exec)
    {
        exec = Execution({
            target: SWAPROUTER_ADDRESS,
            value: 0,
            callData: abi.encodeCall(
                ISwapRouter.exactOutputSingle,
                (
                    ISwapRouter.ExactOutputSingleParams({
                        tokenIn: address(tokenIn),
                        tokenOut: address(tokenOut),
                        fee: SWAPROUTER_DEFAULTFEE,
                        recipient: smartAccount,
                        deadline: block.timestamp,
                        amountOut: amountOut,
                        amountInMaximum: amountInMaximum,
                        sqrtPriceLimitX96: 0
                    })
                )
                )
        });
    }
}
