// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import "test/BaseTest.t.sol";
import "src/ModuleKit.sol";
import { ERC7579ExecutorBase } from "src/Modules.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { UniswapV3Integration } from "src/integrations/uniswap/v3/Uniswap.sol";

contract TestUniswap is BaseTest {
    using ModuleKitHelpers for AccountInstance;
    using UniswapV3Integration for *;

    IERC20 tokenA;
    IERC20 tokenB;
    MockERC20 mockTokenA;
    MockERC20 mockTokenB;

    uint256 amountIn = 100_000_000; // Example: 100 tokens of tokenA
    uint32 slippage = 1; // 0.1% slippage

    address internal constant USDC_HOLDER = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa; // account
    // with USDC holdings
    address internal constant WETH_HOLDER = 0x57757E3D981446D585Af0D9Ae4d7DF6D64647806; // account
    // with WETH holdings

    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public override {
        string memory MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(MAINNET_RPC_URL);
        vm.rollFork(20_426_591);
        instance = makeAccountInstance("account1");
        assertTrue(instance.account != address(0));

        tokenA = IERC20(USDC_ADDRESS);
        tokenB = IERC20(WETH_ADDRESS);

        _fundAccountWithTokenA(amountIn);
        vm.deal(instance.account, 1 ether);
        assertTrue(instance.account.balance == 1 ether);
        instance.simulateUserOp(false);
    }

    function _fundAccountWithTokenA(uint256 amount) internal {
        vm.startPrank(USDC_HOLDER);
        bool success = tokenA.transfer(instance.account, amount);
        require(success, "Failed to transfer tokenA to account");
        vm.stopPrank();
    }

    function testApproveAndSwap() public {
        address poolAddress = UniswapV3Integration.getPoolAddress(address(tokenA), address(tokenB));
        uint160 sqrtPriceX96 = UniswapV3Integration.getSqrtPriceX96(poolAddress);

        uint256 priceRatio = UniswapV3Integration.sqrtPriceX96toPriceRatio(sqrtPriceX96);

        UniswapV3Integration.priceRatioToPrice(priceRatio, poolAddress, address(tokenA));

        bool swapToken0to1 = UniswapV3Integration.checkTokenOrder(address(tokenA), poolAddress);

        uint256 priceRatioLimit;
        if (swapToken0to1) {
            priceRatioLimit = (priceRatio * (1000 - slippage)) / 1000;
        } else {
            priceRatioLimit = (priceRatio * (1000 + slippage)) / 1000;
        }

        UniswapV3Integration.priceRatioToPrice(priceRatioLimit, poolAddress, address(tokenA));

        uint160 sqrtPriceLimitX96 = UniswapV3Integration.priceRatioToSqrtPriceX96(priceRatioLimit);

        uint256 initialAccountBalanceA = tokenA.balanceOf(instance.account);
        uint256 initialAccountBalanceB = tokenB.balanceOf(instance.account);

        Execution[] memory swap = UniswapV3Integration.approveAndSwap(
            instance.account, tokenA, tokenB, amountIn, sqrtPriceLimitX96
        );

        for (uint256 i = 0; i < swap.length; i++) {
            instance.exec({
                target: swap[i].target,
                value: swap[i].value,
                callData: swap[i].callData
            });
        }

        uint256 finalAccountBalanceA = tokenA.balanceOf(instance.account);
        uint256 finalAccountBalanceB = tokenB.balanceOf(instance.account);

        sqrtPriceX96 = UniswapV3Integration.getSqrtPriceX96(poolAddress);

        require(
            finalAccountBalanceA < initialAccountBalanceA,
            "Token A balance in account did not decrease"
        );
        require(
            finalAccountBalanceB > initialAccountBalanceB,
            "Token B balance in account did not increase"
        );
    }
}
