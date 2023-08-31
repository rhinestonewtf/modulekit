// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISwapRouter} from "./ISwapRouter.sol";
import {TransferHelper} from "./TransferHelper.sol";
import "../../executors/IExecutorBase.sol";
import "forge-std/interfaces/IERC20.sol";

address payable constant swapRouter = payable(0xE592427A0AEce92De3Edee1F18E0157C05861564);
uint24 constant poolFee = 3000;

function _swapExactInputSingle(address smartAccount, IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn)
    view
    returns (ExecutorAction memory action)
{
    action.to = (swapRouter);
    // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
    // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
    action.data = abi.encodeWithSelector(
        ISwapRouter.exactInputSingle.selector,
        ISwapRouter.ExactInputSingleParams({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            fee: poolFee,
            recipient: smartAccount,
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0 // DONT RUN THIS IN PROD
        })
    );
}

function _swapExactOutputSingle(
    address smartAccount,
    IERC20 tokenIn,
    IERC20 tokenOut,
    uint256 amountOut,
    uint256 amountInMaximum
) view returns (ExecutorAction memory action) {
    action.to = (swapRouter);
    action.data = abi.encodeWithSelector(
        ISwapRouter.exactOutputSingle.selector,
        ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(tokenIn),
            tokenOut: address(tokenOut),
            fee: poolFee,
            recipient: smartAccount,
            deadline: block.timestamp,
            amountOut: amountOut,
            amountInMaximum: amountInMaximum,
            sqrtPriceLimitX96: 0 // DONT RUN THIS IN PROD
        })
    );
}
