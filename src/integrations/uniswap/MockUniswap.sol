// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/uniswap/v3/ISwapRouter.sol";

contract MockUniswap is ISwapRouter {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    )
        external
        override
    { }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        return params.amountIn;
    }

    function exactInput(ExactInputParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        return params.amountIn;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountIn)
    {
        return params.amountOut;
    }

    function exactOutput(ExactOutputParams calldata params)
        external
        payable
        override
        returns (uint256 amountIn)
    {
        return params.amountOut;
    }
}
