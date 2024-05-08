// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./base/ERC6909.sol";
import "./base/LicenseManagerBase.sol";
import "./base/ProtocolConfig.sol";
import "./base/Subscription.sol";
import "./base/PricingConfig.sol";
import "./lib/Currency.sol";
import "./interfaces/ILicenseManager.sol";
import "./interfaces/IFeeMachine.sol";

import "forge-std/console2.sol";

contract LicenseManager is ILicenseManager, ERC6909, Subscription, Protocol, PricingConfig {
    using CurrencyLibrary for Currency;

    error InvalidClaim();

    constructor(
        IProtocolController controller,
        ISubscription subtoken
    )
        Subscription(subtoken)
        LicenseManagerBase(controller)
    { }

    function settleTransaction(ClaimTransaction calldata claim)
        external
        onlyEnabledModules(msg.sender)
        returns (bool success, uint256 totalAfterFee)
    {
        ModuleRecord storage $moduleRecord = $module[msg.sender];

        Split[] memory split = $moduleRecord.feeMachine.split({ module: msg.sender, claim: claim });
        uint256 total = _mint(claim.currency, split);
        if (total == 0) return (true, claim.amount);

        uint256 protocolFee;
        address beneficiary;
        (protocolFee, total, beneficiary) = addProtocolFee({
            account: claim.account,
            currency: claim.currency,
            module: msg.sender,
            feeMachine: $moduleRecord.feeMachine,
            claimType: ClaimType.Transaction,
            total: total
        });

        _mint({ receiver: beneficiary, id: claim.currency.toId(), amount: protocolFee });

        claim.currency.transferOrApprove(claim.account, total);

        emit TransactionSettled({ account: claim.account, module: msg.sender, amountCharged: total });

        return (true, claim.amount - total);
    }

    function settleSubscription(ClaimSubscription calldata claim)
        external
        onlyEnabledModules(claim.module)
        returns (bool success, uint256 total)
    {
        address account = claim.account;
        address module = claim.module;
        ModuleRecord storage $moduleRecord = $module[claim.module];
        PricingSubscription memory subscriptionRecord = $moduleRecord.subscription;

        uint256 newValidUntil =
            _validUntil({ smartAccount: account, module: module, amount: claim.amount });
        _mintSubscription({ account: account, module: module, newValid: newValidUntil });
        Split[] memory split = $moduleRecord.feeMachine.split({ claim: claim });
        total = _mint(subscriptionRecord.currency, split);
        if (total == 0) return (true, 0);

        uint256 protocolFee;
        address beneficiary;
        (protocolFee, total, beneficiary) = addProtocolFee({
            account: account,
            module: msg.sender,
            currency: subscriptionRecord.currency,
            feeMachine: $moduleRecord.feeMachine,
            claimType: ClaimType.Transaction,
            total: total
        });

        _mint({ receiver: beneficiary, id: subscriptionRecord.currency.toId(), amount: protocolFee });
        subscriptionRecord.currency.transferOrApprove({ account: msg.sender, amount: total });
        emit SubscriptionSettled({ account: account, module: module, amountCharged: total });
        success = true;
    }

    function settlePerUsage(ClaimPerUse calldata claim)
        external
        onlyEnabledModules(msg.sender)
        returns (bool success, uint256 total)
    {
        address account = claim.account;
        address module = msg.sender;

        ModuleRecord storage $moduleRecord = $module[msg.sender];
        PricingPerUse memory perUsePricing = $moduleRecord.perUse;

        Split[] memory split = $moduleRecord.feeMachine.split({ claim: claim });
        total = _mint(perUsePricing.currency, split);

        uint256 protocolFee;
        address beneficiary;
        (protocolFee, total, beneficiary) = addProtocolFee({
            account: account,
            module: msg.sender,
            currency: perUsePricing.currency,
            feeMachine: $moduleRecord.feeMachine,
            claimType: ClaimType.Transaction,
            total: total
        });

        _mint({ receiver: beneficiary, id: perUsePricing.currency.toId(), amount: protocolFee });
        perUsePricing.currency.transferFrom(account, total);

        emit PerUseSettled({ account: account, module: module, amountCharged: total });
        return (true, total);
    }

    function withdraw(Currency currency, uint256 amount) external {
        _burn(msg.sender, currency.toId(), amount);
        currency.transfer(msg.sender, amount);
    }

    function deposit(Currency currency, address receiver, uint256 amount) external {
        currency.transferFrom(msg.sender, amount);
        _mint({ receiver: receiver, id: currency.toId(), amount: amount });
    }

    function _mint(Currency currency, Split[] memory splits) internal returns (uint256 total) {
        uint256 id = currency.toId();

        uint256 length = splits.length;
        for (uint256 i; i < length; i++) {
            address receiver = splits[i].receiver;
            uint256 amount = splits[i].amount;
            total += amount;
            _mint({ receiver: receiver, id: id, amount: amount });
        }
    }
}
