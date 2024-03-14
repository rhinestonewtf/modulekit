// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { HandlerContext } from "@safe-global/safe-contracts/contracts/handler/HandlerContext.sol";
import { MockFallback as MockFallbackBase } from "@rhinestone/modulekit/src/mocks/MockFallback.sol";

import "forge-std/console2.sol";

contract MockFallback is MockFallbackBase, HandlerContext {
    function target(uint256 value)
        external
        returns (uint256 _value, address msgSender, address msgSenderContext)
    {
        _value = value;
        msgSender = msg.sender;
        msgSenderContext = _msgSender();
    }

    function target2(uint256 value)
        external
        returns (uint256 _value, address _this, address msgSender)
    {
        _value = value;
        _this = address(this);
        msgSender = msg.sender;
    }
}
