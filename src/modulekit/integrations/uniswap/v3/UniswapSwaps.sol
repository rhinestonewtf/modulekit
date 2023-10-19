// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/MainnetAddresses.sol";
import "../../interfaces/uniswap/v3/ISwapRouter.sol";
import "../../ERC20Actions.sol";
import "../../../IExecutor.sol";

/// @author zeroknots

library UniswapSwaps {
    using ModuleExecLib for IExecutorManager;
    using ERC20ModuleKit for address;

    function swapExactInputSingle(
        address smartAccount,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    )
        internal
        view
        returns (ExecutorAction memory action)
    {
        action.to = SWAPROUTER_ADDRESS;
        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        action.data = abi.encodeWithSelector(
            ISwapRouter.exactInputSingle.selector,
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(tokenIn),
                tokenOut: address(tokenOut),
                fee: SWAPROUTER_DEFAULTFEE,
                recipient: smartAccount,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
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
        returns (ExecutorAction memory action)
    {
        action.to = SWAPROUTER_ADDRESS;
        action.data = abi.encodeWithSelector(
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
        );
    }
}
