// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SWAPROUTER_ADDRESS, SWAPROUTER_DEFAULTFEE, QUOTER_ADDRESS} from "../helpers/MainnetAddresses.sol";
import {ISwapRouter} from "../../interfaces/uniswap/v3/ISwapRouter.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC20Integration} from "../../ERC20.sol";
import {Execution} from "../../../Accounts.sol";

/// @author zeroknots
library UniswapV3Integration {
    using ERC20Integration for IERC20;

    function approveAndSwap(
        address smartAccount,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) internal view returns (Execution[] memory exec) {
        exec = new Execution[](3);
        (exec[0], exec[1]) = ERC20Integration.safeApprove(
            tokenIn,
            SWAPROUTER_ADDRESS,
            amountIn
        );
        exec[2] = swapExactInputSingle(
            smartAccount,
            tokenIn,
            tokenOut,
            amountIn,
            sqrtPriceLimitX96
        );
    }

    function swapExactInputSingle(
        address smartAccount,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) internal view returns (Execution memory exec) {
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
    ) internal view returns (Execution memory exec) {
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

    function getQuote(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external view returns (uint256) {
        IUniswapV3Quoter quoter = IUniswapV3Quoter(quoterAddress);

        (bool success, bytes memory data) = address(quoter).staticcall(
            abi.encodeWithSelector(
                quoter.quoteExactInputSingle.selector,
                tokenIn,
                tokenOut,
                fee,
                amountIn,
                sqrtPriceLimitX96
            )
        );

        require(success, "Static call failed");

        uint256 amountOut = abi.decode(data, (uint256));
        return amountOut;
    }

    // Babylonian method for square root calculation
    function sqrt(uint256 y) returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // Helper function to calculate sqrtPriceLimitX96
    function calculateSqrtPriceLimitX96(uint256 priceRatio) returns (uint160) {
        // Step 1: Calculate the square root of the price ratio
        uint256 sqrtPriceRatio = sqrt(priceRatio * 1e18); // Scale priceRatio to 18 decimals for precision

        // Step 2: Scale the result by 2^96
        uint256 sqrtPriceLimitX96 = (sqrtPriceRatio * 2 ** 96) / 1e9; // Adjust back from the scaling

        return uint160(sqrtPriceLimitX96);
    }
}
