// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "forge-std/interfaces/IERC20.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract ForkTest is Test {
    uint256 mainnetFork;

    string MAINNET_RPC_URL = vm.rpcUrl("mainnet");
    ISwapRouter SWAPROUTER = ISwapRouter(address(0xE592427A0AEce92De3Edee1F18E0157C05861564));
    IERC20 weth = IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address poolFactory = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function setUp() public virtual {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);

        vm.selectFork(mainnetFork);
        vm.rollFork(19_559_321);
    }
}
