// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    SWAPROUTER_ADDRESS,
    SWAPROUTER_DEFAULTFEE,
    WETH_ADDRESS
} from "../helpers/MainnetAddresses.sol";
import { ISwapRouter } from "../../interfaces/uniswap/v3/ISwapRouter.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ERC20Integration } from "../../ERC20.sol";
import { IERC7579Account, Execution } from "../../../Accounts.sol";

/// @title UniswapV3Integration
/// @author zeroknots
/// @notice This library provides functions to interact with Uniswap V3
library UniswapV3Integration {
    using ERC20Integration for IERC20;

    /// @notice Approves the Uniswap router to spend `amountIn` of `tokenIn` and then swaps
    /// `tokenIn` for `tokenOut`
    /// @param smartAccount The address of the smart account
    /// @param tokenIn The token to be swapped
    /// @param tokenOut The token to be received
    /// @param amountIn The amount of `tokenIn` to be swapped
    /// @param sqrtPriceLimitX96 The price limit of the swap
    /// @return exec An array of Execution objects representing the approve and swap operations
    function approveAndSwapExactInput(
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
        exec[1] =
            swapExactInputSingle(smartAccount, tokenIn, amountIn, tokenOut, 0, sqrtPriceLimitX96);
    }

    /// @notice Swaps `amountIn` of `tokenIn` for at least `amountOutMinimum` of `tokenOut` using
    /// the exact input method
    /// @param smartAccount The address of the smart account
    /// @param tokenIn The token to be swapped
    /// @param amountIn The amount of `tokenIn` to be swapped
    /// @param tokenOut The token to be received
    /// @param amountOutMinimum The minimum amount of `tokenOut` to be received
    /// @param sqrtPriceLimitX96 The price limit of the swap
    /// @return exec An Execution object representing the swap operation
    function swapExactInputSingle(
        address smartAccount,
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    )
        internal
        view
        returns (Execution memory exec)
    {
        exec = Execution({
            target: SWAPROUTER_ADDRESS,
            value: address(tokenIn) == WETH_ADDRESS ? amountIn : 0,
            callData: abi.encodeWithSelector(
                ISwapRouter.exactInputSingle.selector,
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(tokenIn),
                    tokenOut: address(tokenOut),
                    fee: SWAPROUTER_DEFAULTFEE,
                    recipient: smartAccount,
                    deadline: block.timestamp,
                    amountIn: amountIn,
                    amountOutMinimum: amountOutMinimum,
                    sqrtPriceLimitX96: sqrtPriceLimitX96
                })
                )
        });
    }

    /// @notice Swaps `tokenIn` for exactly `amountOut` of `tokenOut` using the exact output method
    /// @param smartAccount The address of the smart account
    /// @param tokenIn The token to be swapped
    /// @param amountInMaximum The maximum amount of `tokenIn` to be swapped
    /// @param tokenOut The token to be received
    /// @param amountOut The exact amount of `tokenOut` to be received
    /// @return exec An Execution object representing the swap operation
    function swapExactOutputSingle(
        address smartAccount,
        IERC20 tokenIn,
        uint256 amountInMaximum,
        IERC20 tokenOut,
        uint256 amountOut
    )
        internal
        view
        returns (Execution memory exec)
    {
        exec = Execution({
            target: SWAPROUTER_ADDRESS,
            value: address(tokenIn) == WETH_ADDRESS ? amountInMaximum : 0,
            callData: abi.encodeWithSelector(
                ISwapRouter.exactOutputSingle.selector,
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
        });
    }
}
