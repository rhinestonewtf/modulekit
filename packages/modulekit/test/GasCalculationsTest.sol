// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "src/test/utils/GasCalculations.sol";

contract GasCalculationsTest is DSTest {
 
    function test_formatGasValue() public {
        uint256 prevValue = 37054;
        uint256 newValue = 187170;

        string memory result = formatGasValue(prevValue, newValue);

        // Log the result
        emit log_named_string("Result", result);
    }

    function test_formatGas() public {
        int256 value = 2550948;

        string memory result = formatGas(value);

        // Log the result
        emit log_named_string("Result", result);
    }
}