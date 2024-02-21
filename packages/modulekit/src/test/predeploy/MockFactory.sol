// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
/* solhint-enable no-unused-import */

import { MockUniswap, ISwapRouter } from "../../integrations/uniswap/MockUniswap.sol";
import { SWAPROUTER_ADDRESS } from "../../integrations/uniswap/helpers/MainnetAddresses.sol";
import { etch } from "../utils/Vm.sol";

contract MockFactory {
    ISwapRouter public uniswap;

    constructor() {
        MockUniswap _mockUniswap = new MockUniswap();
        etch(SWAPROUTER_ADDRESS, address(_mockUniswap).code);
        uniswap = ISwapRouter(SWAPROUTER_ADDRESS);
    }
}
