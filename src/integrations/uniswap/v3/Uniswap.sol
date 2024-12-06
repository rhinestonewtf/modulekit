// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Helpers
import {
    SWAPROUTER_ADDRESS,
    SWAPROUTER_DEFAULTFEE,
    FACTORY_ADDRESS
} from "../helpers/MainnetAddresses.sol";

// Interfaces
import { ISwapRouter } from "../../interfaces/uniswap/v3/ISwapRouter.sol";
import { IUniswapV3Factory } from "../../interfaces/uniswap/v3/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "../../interfaces/uniswap/v3/IUniswapV3Pool.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

// Dependencies
import { ERC20Integration } from "../../ERC20.sol";

// Types
import { Execution } from "../../../accounts/erc7579/lib/ExecutionLib.sol";

/// @author zeroknots
library UniswapV3Integration {
    using ERC20Integration for IERC20;

    error PoolDoesNotExist();

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
        exec = new Execution[](3);
        (exec[0], exec[1]) = ERC20Integration.safeApprove(tokenIn, SWAPROUTER_ADDRESS, amountIn);
        exec[2] = swapExactInputSingle(smartAccount, tokenIn, tokenOut, amountIn, sqrtPriceLimitX96);
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

    function getPoolAddress(
        address token0,
        address token1
    )
        public
        view
        returns (address poolAddress)
    {
        IUniswapV3Factory factory = IUniswapV3Factory(FACTORY_ADDRESS);
        poolAddress = factory.getPool(token0, token1, SWAPROUTER_DEFAULTFEE);
        if (poolAddress == address(0)) {
            revert PoolDoesNotExist();
        }
        return poolAddress;
    }

    function getSqrtPriceX96(address poolAddress) public view returns (uint160 sqrtPriceX96) {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        IUniswapV3Pool.Slot0 memory slot0 = pool.slot0();
        sqrtPriceX96 = slot0.sqrtPriceX96;
    }

    function sqrtPriceX96toPriceRatio(uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 priceRatio)
    {
        uint256 decodedSqrtPrice = (sqrtPriceX96 * 10 ** 9) / (2 ** 96);
        priceRatio = decodedSqrtPrice * decodedSqrtPrice;
    }

    function priceRatioToPrice(
        uint256 priceRatio,
        address poolAddress,
        address tokenSwappedFrom
    )
        internal
        view
        returns (uint256 price)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        address poolToken0 = pool.token0();
        address poolToken1 = pool.token1();
        uint256 token0Decimals = IERC20(poolToken0).decimals();
        uint256 token1Decimals = IERC20(poolToken1).decimals();

        bool swapToken0to1 = (tokenSwappedFrom == poolToken0);
        if (swapToken0to1) {
            price = (10 ** token1Decimals * 10 ** 18) / priceRatio;
        } else {
            price = (priceRatio * 10 ** token0Decimals) / 10 ** 18;
        }
        return price;
    }

    function priceRatioToSqrtPriceX96(uint256 priceRatio) internal pure returns (uint160) {
        // Scale priceRatio to 18 decimals for precision
        uint256 sqrtPriceRatio = sqrt256(priceRatio);

        uint256 sqrtPriceX96 = (sqrtPriceRatio * 2 ** 96) / 1e9; // Adjust back from the scaling

        return uint160(sqrtPriceX96);
    }

    function checkTokenOrder(
        address tokenSwappedFrom,
        address poolAddress
    )
        internal
        view
        returns (bool swapToken0to1)
    {
        address poolToken0 = IUniswapV3Pool(poolAddress).token0();
        swapToken0to1 = (tokenSwappedFrom == poolToken0);
    }

    function sqrt256(uint256 y) internal pure returns (uint256 z) {
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
}
