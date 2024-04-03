// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../lib/CallbackValidation.sol";
import "../DataTypes.sol";
import "../lib/TickMath.sol";
import "../lib/Path.sol";

import "forge-std/console2.sol";

abstract contract Swapper {
    using Path for bytes;

    ISwapRouter internal immutable SWAP_ROUTER;

    struct SwapConf {
        address tokenOut;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    SwapConf internal swapConf;
    /// @dev Used as the placeholder value for amountInCached, because the computed amount in for an
    /// exact output swap
    /// can never actually be this value
    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

    address public immutable factory;
    address internal FEE_TOKEN;

    /// @dev Transient storage variable used for returning the computed amount in for an exact
    /// output swap.
    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

    constructor(address _factory, address _feeToken) {
        factory = _factory;
        FEE_TOKEN = _feeToken;
    }

    function setConf(SwapConf calldata _conf) external {
        swapConf = _conf;
    }

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    )
        private
        view
        returns (IUniswapV3Pool)
    {
        return IUniswapV3Pool(
            PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee))
        );
    }

    struct SwapCallbackData {
        bytes path;
        address payer;
        Claim claim;
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    )
        external
    {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions
            // are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();
        // validate that callpack comes from correct pool
        CallbackValidation.verifyCallback(factory, tokenIn, tokenOut, fee);

        (bool isExactInput, uint256 amountToPay) = amount0Delta > 0
            ? (tokenIn < tokenOut, uint256(amount0Delta))
            : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            _permitPay(tokenIn, data.payer, msg.sender, amountToPay, data.claim);
        } else {
            // either initiate the next swap or pay
            if (data.path.hasMultiplePools()) {
                data.path = data.path.skipToken();
                exactOutputInternal(amountToPay, msg.sender, 0, data);
            } else {
                amountInCached = amountToPay;
                tokenIn = tokenOut; // swap in/out because exact output swaps are reversed
                _permitPay(tokenIn, data.payer, msg.sender, amountToPay, data.claim);
            }
        }
    }
    /// @dev Performs a single exact output swap

    function _permitPay(
        address token,
        address payer,
        address receiver,
        uint256 amount,
        Claim memory claim
    )
        internal
        virtual;

    function exactOutputInternal(
        uint256 amountOut,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    )
        private
        returns (uint256 amountIn)
    {
        // allow swapping to the router address with address 0
        if (recipient == address(0)) recipient = address(this);

        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();

        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0Delta, int256 amount1Delta) = getPool(tokenIn, tokenOut, fee).swap(
            recipient,
            zeroForOne,
            -int256(amountOut),
            sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : sqrtPriceLimitX96,
            abi.encode(data)
        );

        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = zeroForOne
            ? (uint256(amount0Delta), uint256(-amount1Delta))
            : (uint256(amount1Delta), uint256(-amount0Delta));
        // it's technically possible to not receive the full output amount,
        // so if no price limit has been specified, require this possibility away
        if (sqrtPriceLimitX96 == 0) require(amountOutReceived == amountOut);
    }

    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 amountOut;
        uint160 sqrtPriceLimitX96;
        address payer;
        address recipient;
    }

    function exactOutputSingle(
        SwapParams memory params,
        Claim memory claim
    )
        internal
        returns (uint256 amountIn)
    {
        // avoid an SLOAD by using the swap return data
        amountIn = exactOutputInternal(
            params.amountOut,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({
                path: abi.encodePacked(params.tokenIn, params.fee, params.tokenOut),
                payer: params.payer,
                claim: claim
            })
        );

        // require(amountIn <= amountInMaximum, "Too much requested");
        // has to be reset even though we don't use it in the single hop case
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }
}
