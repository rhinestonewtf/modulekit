// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol"; // Import Foundry's Test library
import {UniswapV3Integration} from "../src/integrations/uniswap/v3/Uniswap.sol";

contract TestUniswap is Test {
    address constant CHAINLINK_ETH_USD_AGGREGATOR =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Example ETH/USD Aggregator

    function testGetPrice() public {
        int latestPrice = UniswapV3Integration.getLatestPrice(
            CHAINLINK_ETH_USD_AGGREGATOR
        );
        emit log_named_int("Latest ETH/USD Price", latestPrice);
    }
}

// pragma solidity ^0.8.25;

// import "test/BaseTest.t.sol";
// import "forge-std/Test.sol"; // Import Foundry's Test library
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {UniswapV3Integration} from "../src/integrations/uniswap/v3/Uniswap.sol";

// contract TestUniswap is Test {
//     // Instance of UniswapV3Integration library
//     using UniswapV3Integration for *;

//     // Mock ERC20 tokens for testing
//     IERC20 tokenA;
//     IERC20 tokenB;

//     constructor() {
//         // Initialize mock ERC20 tokens
//         tokenA = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)); // Replace with mock ERC20 token A address
//         tokenB = IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)); // Replace with mock ERC20 token B address
//     }

//     // Example test function to call getQuote
//     function testGetQuote() public {
//         uint256 amountIn = 100000000; // Example: 100 tokens of tokenA
//         uint24 fee = 3000; // Example fee tier

//         // Log input values
//         emit log_named_address("Token A Address", address(tokenA));
//         emit log_named_address("Token B Address", address(tokenB));
//         emit log_named_uint("Amount In", amountIn);
//         emit log_named_uint("Fee", fee);

//         // Call getQuote function from UniswapV3Integration library
//         uint256 quoteAmount;
//         try
//             UniswapV3Integration.getQuote(
//                 address(tokenA),
//                 address(tokenB),
//                 fee,
//                 amountIn
//             )
//         returns (uint256 result) {
//             quoteAmount = result;
//         } catch Error(string memory reason) {
//             emit log_string(reason); // Log revert reason
//             revert(reason);
//         } catch (bytes memory lowLevelData) {
//             emit log_bytes(lowLevelData); // Log low level data if an unknown error occurs
//             revert("Unknown error occurred during getQuote call");
//         }

//         // Log the quote amount
//         emit log_named_uint("Quote Amount", quoteAmount);
//     }
// }
