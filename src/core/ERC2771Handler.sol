// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { HandlerContext } from "erc7579/utils/HandlerContext.sol";

contract ERC2771Handler is HandlerContext {
    error ERC2771Unauthorized();

    modifier onlySmartAccount() {
        if (msg.sender != _msgSender()) {
            revert ERC2771Unauthorized();
        }
        _;
    }
}
