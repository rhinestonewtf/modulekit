// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./lib/Currency.sol";
import "./interfaces/IFeeMachine.sol";

enum ClaimType {
    Transaction,
    Subscription
}

struct ClaimTransaction {
    address account;
    Currency currency;
    uint256 amount;
    bytes feeMachineData;
    address referral;
}

struct ClaimSubscription {
    address account;
    address module;
    uint256 amount;
    bytes feeMachineData;
    address referral;
}

struct ClaimPerUse {
    address account;
    bytes feeMachineData;
    address referral;
}

struct SubscriptionRecord {
    uint48 validUntil;
    uint48 renewalSeconds;
}

struct PerUseRecord {
    Currency currency;
    uint256 amount;
}

struct SubscriptionPricing {
    Currency currency;
    uint128 pricePerSecond;
    uint128 minSubTime;
}

struct Split {
    address beneficiary;
    uint256 amount;
}

struct ModuleFee {
    bool enabled;
    IFeeMachine feeMachine;
    address developer;
}
