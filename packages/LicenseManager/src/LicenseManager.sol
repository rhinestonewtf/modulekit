// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./base/ERC6909.sol";
import "./base/ModuleRegister.sol";
import "./base/ProtocolConfig.sol";
import "./base/Subscription.sol";
import "./base/PricingConfig.sol";
import "./lib/Currency.sol";
import "./lib/MintLib.sol";
import "./interfaces/ILicenseManager.sol";
import "./interfaces/IFeeMachine.sol";

import "forge-std/console2.sol";

contract LicenseManager is ILicenseManager, ERC6909, Subscription, PricingConfig {
    using CurrencyLibrary for Currency;
    using MintLib for mapping(address => mapping(uint256 => uint256));

    error InvalidClaim();

    constructor(
        IProtocolController controller,
        ISubscription subtoken
    )
        Subscription(subtoken)
        ProtocolConfig(controller)
    { }

    function settleTransaction(ClaimTransaction calldata claim)
        external
        onlyEnabledModules(msg.sender)
        returns (bool success, uint256 remaining)
    {
        address module = msg.sender;
        ModuleRecord storage $moduleRecord = $module[module];
        uint256 total;

        IFeeMachine feeMachine = $moduleRecord.feeMachine;
        if (address(feeMachine) != address(0)) {
            Split[] memory splits =
                $moduleRecord.feeMachine.split({ module: msg.sender, claim: claim });
            total = balanceOf.mint({ currency: claim.currency, splits: splits });
        }
        if (total == 0) return (true, claim.amount);

        (uint256 protocolFee, address receiver) = getProtocolFee({
            account: claim.account,
            currency: claim.currency,
            module: module,
            feeMachine: $moduleRecord.feeMachine,
            claimType: ClaimType.Transaction,
            total: total
        });
        balanceOf.mint({ receiver: receiver, id: claim.currency.toId(), amount: protocolFee });
        total += protocolFee;

        claim.currency.transferOrApprove(claim.account, total);
        emit TransactionSettled({ account: claim.account, module: module, amountCharged: total });

        return (true, claim.amount - total);
    }

    function settleSubscription(ClaimSubscription calldata claim)
        external
        onlyEnabledModules(claim.module)
        returns (bool success, uint256 remaining)
    {
        address account = claim.account;
        address module = claim.module;
        uint256 total;
        ModuleRecord storage $moduleRecord = $module[claim.module];
        Currency currency = $moduleRecord.subscription.currency;

        subtoken.mint({
            account: account,
            module: module,
            validUntil: _validUntil({ smartAccount: account, module: module, amount: claim.amount })
        });

        IFeeMachine feeMachine = $moduleRecord.feeMachine;
        if (address(feeMachine) != address(0)) {
            Split[] memory splits = $moduleRecord.feeMachine.split({ claim: claim });
            total = balanceOf.mint({ currency: currency, splits: splits });
        }
        if (total == 0) return (true, claim.amount);

        (uint256 protocolFee, address receiver) = getProtocolFee({
            account: account,
            module: claim.module,
            currency: currency,
            feeMachine: feeMachine,
            claimType: ClaimType.Subscription,
            total: total
        });

        balanceOf.mint({ receiver: receiver, id: currency.toId(), amount: protocolFee });
        total += protocolFee;
        currency.transferOrApprove({ account: account, amount: total });
        emit SubscriptionSettled({ account: account, module: module, amountCharged: total });
        return (true, claim.amount - total);
    }

    function settlePerUsage(ClaimPerUse calldata claim)
        external
        onlyEnabledModules(msg.sender)
        returns (bool success, uint256 total)
    {
        address account = claim.account;
        address module = msg.sender;

        ModuleRecord storage $moduleRecord = $module[module];
        PricingPerUse memory perUsePricing = $moduleRecord.perUse;

        Currency currency = $moduleRecord.perUse.currency;

        Split[] memory splits = $moduleRecord.feeMachine.split({ claim: claim });
        total = balanceOf.mint({ currency: currency, splits: splits });

        (uint256 protocolFee, address receiver) = getProtocolFee({
            account: account,
            module: module,
            currency: currency,
            feeMachine: $moduleRecord.feeMachine,
            claimType: ClaimType.Transaction,
            total: total
        });

        balanceOf.mint({ receiver: receiver, id: currency.toId(), amount: protocolFee });
        perUsePricing.currency.transferFrom(account, total);

        emit PerUseSettled({ account: account, module: module, amountCharged: total });
        return (true, total);
    }

    function withdraw(Currency currency, uint256 amount) external {
        balanceOf.burn({ sender: msg.sender, id: currency.toId(), amount: amount });
        currency.transfer(msg.sender, amount);
    }

    function deposit(Currency currency, address receiver, uint256 amount) external {
        balanceOf.mint({ receiver: receiver, id: currency.toId(), amount: amount });
        currency.transferFrom(msg.sender, amount);
    }
}
