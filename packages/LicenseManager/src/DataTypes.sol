// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./lib/Currency.sol";
import "./interfaces/IFeeMachine.sol";

enum ClaimType {
    Transaction,
    Subscription,
    PerUse
}

struct Split {
    address receiver;
    uint256 amount;
}

struct Authorization {
    bool allowTransaction;
    bool allowSubscription;
    bool allowPerUse;
}

/*´:°•.°+.*•´.*˚ .°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                          Claims                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                      Module Pricing                        */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

struct ModuleRecord {
    bool enabled;
    address authority;
    IFeeMachine feeMachine;
    PricingSubscription subscription;
    PricingPerUse perUse;
    PricingTransaction transaction;
}

struct PricingTransaction {
    uint256 bps;
}

struct PricingPerUse {
    Currency currency;
    uint128 pricePerUsage;
}

struct PricingSubscription {
    Currency currency;
    uint128 pricePerSecond;
    uint128 minSubTime;
}

struct SubscriptionRecord {
    uint48 validUntil;
    uint48 renewalSeconds;
}
