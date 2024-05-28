// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    AccountType,
    MULTI_ACCOUNT_FACTORY_ADDRESS,
    MultiAccountFactory
} from "./MultiAccountFactory.sol";

function getAccountType() view returns (AccountType env) {
    env = MultiAccountFactory(MULTI_ACCOUNT_FACTORY_ADDRESS).getAccountType();
}
