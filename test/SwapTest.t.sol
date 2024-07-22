// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "test/BaseTest.t.sol";
import "src/ModuleKit.sol";
import {ERC7579ExecutorBase} from "src/Modules.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {UniswapV3Integration} from "../src/integrations/uniswap/v3/Uniswap.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract TestUniswap is RhinestoneModuleKit, BaseTest {
    using ModuleKitHelpers for AccountInstance;
    using UniswapV3Integration for *;

    IERC20 tokenA;
    IERC20 tokenB;

    // Chainlink price feed for WETH/USDC
    AggregatorV3Interface internal priceFeed;

    // Amount to be used in the test
    uint256 amountIn = 100000000; // Example: 100 tokens of tokenA

    address internal constant TOKEN_A_HOLDER =
        0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa; // account with USDC holdings

    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant CHAINLINK_PRICE_FEED_ADDRESS =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    function setUp() public override {
        instance = makeAccountInstance("account1");
        assertTrue(instance.account != address(0));

        // Initialize mock ERC20 tokens
        tokenA = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)); // USDC
        tokenB = IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)); // WETH

        priceFeed = AggregatorV3Interface(CHAINLINK_PRICE_FEED_ADDRESS);

        // Fund the smart account with tokenA
        fundContractWithTokenA(amountIn);

        // Fund the smart account with Ether for gas
        vm.deal(instance.account, 1 ether);
        assertTrue(instance.account.balance == 1 ether);
    }

    function fundContractWithTokenA(uint256 amount) internal {
        vm.startPrank(TOKEN_A_HOLDER);

        // bool success = tokenA.transfer(address(this), amount);
        // require(success, "Failed to transfer tokenA");

        bool success = tokenA.transfer(instance.account, amount);
        require(success, "Failed to transfer tokenA to smart account");

        vm.stopPrank();
    }

    function testApproveAndSwap() public {
        // Get the latest price from Chainlink
        int latestPrice = UniswapV3Integration.getLatestPrice(
            CHAINLINK_PRICE_FEED_ADDRESS
        );
        emit log_named_int("Latest Price from Chainlink", latestPrice);

        uint160 sqrtPriceLimitX96 = UniswapV3Integration
            .getAdjustedSqrtPriceX96(address(tokenA), address(tokenB));
        emit log_named_uint("Calculated sqrtPriceLimitX96", sqrtPriceLimitX96);

        // Record initial balances
        uint256 initialBalanceA = tokenA.balanceOf(address(this));
        uint256 initialBalanceB = tokenB.balanceOf(address(this));
        uint256 initialAccountBalanceA = tokenA.balanceOf(instance.account);
        uint256 initialAccountBalanceB = tokenB.balanceOf(instance.account);

        emit log_named_uint(
            "Initial Balance of Token A (contract)",
            initialBalanceA
        );
        emit log_named_uint(
            "Initial Balance of Token B (contract)",
            initialBalanceB
        );
        emit log_named_uint(
            "Initial Balance of Token A (account)",
            initialAccountBalanceA
        );
        emit log_named_uint(
            "Initial Balance of Token B (account)",
            initialAccountBalanceB
        );

        Execution[] memory swap = UniswapV3Integration.approveAndSwap(
            instance.account,
            tokenA,
            tokenB,
            amountIn,
            sqrtPriceLimitX96
        );

        for (uint256 i = 0; i < swap.length; i++) {
            instance.exec({
                target: swap[i].target,
                value: swap[i].value,
                callData: swap[i].callData
            });
        }

        uint160 latestSqrtPriceX96 = UniswapV3Integration.getSqrtPriceX96(
            address(tokenA),
            address(tokenB)
        );
        emit log_named_uint("Latest Square Root Price X96", latestSqrtPriceX96);

        uint256 finalBalanceA = tokenA.balanceOf(address(this));
        uint256 finalBalanceB = tokenB.balanceOf(address(this));
        uint256 finalAccountBalanceA = tokenA.balanceOf(instance.account);
        uint256 finalAccountBalanceB = tokenB.balanceOf(instance.account);

        emit log_named_uint(
            "Final Balance of Token A (contract)",
            finalBalanceA
        );
        emit log_named_uint(
            "Final Balance of Token B (contract)",
            finalBalanceB
        );
        emit log_named_uint(
            "Final Balance of Token A (account)",
            finalAccountBalanceA
        );
        emit log_named_uint(
            "Final Balance of Token B (account)",
            finalAccountBalanceB
        );

        // Check that the balances have changed as expected
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
