// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { HandlerContext } from "@safe-global/safe-contracts/contracts/handler/HandlerContext.sol";
import { MockFallback as MockFallbackBase } from "modulekit/src/mocks/MockFallback.sol";

contract MockFallback is MockFallbackBase, HandlerContext {
    function target(uint256 value)
        external
        returns (uint256 _value, address erc2771Sender, address msgSender)
    {
        _value = value;
        erc2771Sender = _msgSender();
        msgSender = msg.sender;
    }
}
