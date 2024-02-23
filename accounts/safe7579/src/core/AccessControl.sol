// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { HandlerContext } from "@safe-global/safe-contracts/contracts/handler/HandlerContext.sol";
import { AccountBase } from "erc7579/core/AccountBase.sol";

contract AccessControl is HandlerContext, AccountBase {
    modifier onlyEntryPointOrSelf() virtual override {
        if (!(_msgSender() == entryPoint() || msg.sender == _msgSender())) {
            revert AccountAccessUnauthorized();
        }
        _;
    }

    function entryPoint() public view virtual override returns (address) {
        return 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    }
}
