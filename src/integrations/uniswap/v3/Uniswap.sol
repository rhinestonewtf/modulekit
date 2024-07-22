// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SWAPROUTER_ADDRESS, SWAPROUTER_DEFAULTFEE, FACTORY_ADDRESS} from "../helpers/MainnetAddresses.sol";
import {ISwapRouter} from "../../interfaces/uniswap/v3/ISwapRouter.sol";
import {IUniswapV3Factory} from "../../interfaces/uniswap/v3/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "../../interfaces/uniswap/v3/IUniswapV3Pool.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC20Integration} from "../../ERC20.sol";
import {Execution} from "../../../Accounts.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "forge-std/console.sol"; // Import console for logging

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

    // Function to get the latest price from a Chainlink oracle
    function getLatestPrice(address _priceFeed) internal view returns (int) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (, int price, , , ) = priceFeed.latestRoundData();
        return price;
    }

    function getSqrtPriceX96(
        address token0,
        address token1
    ) public view returns (uint160 sqrtPriceX96) {
        IUniswapV3Factory factory = IUniswapV3Factory(FACTORY_ADDRESS);
        address poolAddress = factory.getPool(
            token0,
            token1,
            SWAPROUTER_DEFAULTFEE
        );
        require(poolAddress != address(0), "Pool does not exist");
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        IUniswapV3Pool.Slot0 memory slot0 = pool.slot0();
        uint160 sqrtPriceX96 = slot0.sqrtPriceX96;

        return sqrtPriceX96; // Added return statement
    }

    function getAdjustedSqrtPriceX96(
        address token0,
        address token1
    ) external view returns (uint160 newSqrtPriceX96) {
        uint160 sqrtPriceX96 = getSqrtPriceX96(token0, token1);

        console.log("Raw sqrtPriceX96:", sqrtPriceX96);

        uint256 decodedSqrtPrice = sqrtPriceX96 / (2 ** 96);

        uint256 price = decodedSqrtPrice * decodedSqrtPrice;

        console.log("Converted Price:", price);

        // Correctly calculate the new price with a 0.1% decrease
        uint256 decreasedPrice = (price * 999) / 1000; // Corrected calculation

        console.log("Decreased Price:", decreasedPrice);

        newSqrtPriceX96 = calculateSqrtPriceX96(decreasedPrice); // Assuming calculateSqrtPriceX96 is correctly implemented elsewhere

        console.log("New sqrtPriceX96:", newSqrtPriceX96);

        return newSqrtPriceX96;
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

    function calculateSqrtPriceX96(
        uint256 priceRatio
    ) internal pure returns (uint160) {
        uint256 sqrtPriceRatio = sqrt256(priceRatio * 1e18); // Scale priceRatio to 18 decimals for precision

        uint256 sqrtPriceX96 = (sqrtPriceRatio * 2 ** 96) / 1e9; // Adjust back from the scaling

        return uint160(sqrtPriceX96);
    }
}
