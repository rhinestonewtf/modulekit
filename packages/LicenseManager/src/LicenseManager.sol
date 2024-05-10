// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./base/ERC6909.sol";
import "./base/ModuleRegister.sol";
import "./base/FeeAuthorization.sol";
import "./base/ProtocolConfig.sol";
import "./base/Subscription.sol";
import "./base/PricingConfig.sol";
import "./lib/Currency.sol";
import "./lib/MintLib.sol";
import "./interfaces/ILicenseManager.sol";
import "./interfaces/IFeeMachine.sol";

import "forge-std/console2.sol";

contract LicenseManager is
    ILicenseManager,
    FeeAuthorization,
    ERC6909,
    Subscription,
    PricingConfig
{
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
        onlyAuthorizedModule(claim.account, msg.sender, ClaimType.Transaction)
        returns (uint256 amountCharged)
    {
        ModuleRecord storage $moduleRecord = $module[msg.sender];

        IFeeMachine feeMachine = $moduleRecord.feeMachine;
        amountCharged = balanceOf.mint({
            currency: claim.currency,
            splits: feeMachine.split({ module: msg.sender, claim: claim })
        });

        (uint256 protocolFee, address receiver) = getProtocolFee({
            account: claim.account,
            currency: claim.currency,
            module: msg.sender,
            feeMachine: feeMachine,
            claimType: ClaimType.Transaction,
            total: amountCharged
        });
        balanceOf.mint({ receiver: receiver, id: claim.currency.toId(), amount: protocolFee });
        amountCharged += protocolFee;

        claim.currency.transferOrApprove(claim.account, amountCharged);
        emit TransactionSettled({
            account: claim.account,
            module: msg.sender,
            amountCharged: amountCharged
        });
    }

    function settleSubscription(ClaimSubscription calldata claim)
        external
        onlyEnabledModules(claim.module)
        onlyAuthorizedModule(msg.sender, claim.module, ClaimType.Subscription)
        returns (uint256 amountCharged)
    {
        ModuleRecord storage $moduleRecord = $module[claim.module];
        Currency currency = $moduleRecord.subscription.currency;

        subtoken.mint({
            account: claim.account,
            module: claim.module,
            validUntil: _validUntil({
                smartAccount: claim.account,
                module: claim.module,
                amount: claim.amount
            })
        });

        IFeeMachine feeMachine = $moduleRecord.feeMachine;
        amountCharged = balanceOf.mint({
            currency: currency,
            splits: $moduleRecord.feeMachine.split({ claim: claim })
        });

        (uint256 protocolFee, address receiver) = getProtocolFee({
            account: claim.account,
            module: claim.module,
            currency: currency,
            feeMachine: feeMachine,
            claimType: ClaimType.Subscription,
            total: amountCharged
        });

        balanceOf.mint({ receiver: receiver, id: currency.toId(), amount: protocolFee });
        amountCharged += protocolFee;
        currency.transferOrApprove({ account: claim.account, amount: amountCharged });
        emit SubscriptionSettled({
            account: claim.account,
            module: claim.module,
            amountCharged: amountCharged
        });
    }

    function settlePerUsage(ClaimPerUse calldata claim)
        external
        onlyEnabledModules(msg.sender)
        onlyAuthorizedModule(claim.account, msg.sender, ClaimType.PerUse)
        returns (uint256 amountCharged)
    {
        ModuleRecord storage $moduleRecord = $module[msg.sender];

        Currency currency = $moduleRecord.perUse.currency;

        IFeeMachine feeMachine = $moduleRecord.feeMachine;
        amountCharged =
            balanceOf.mint({ currency: currency, splits: feeMachine.split({ claim: claim }) });

        (uint256 protocolFee, address receiver) = getProtocolFee({
            account: claim.account,
            module: msg.sender,
            currency: currency,
            feeMachine: feeMachine,
            claimType: ClaimType.PerUse,
            total: amountCharged
        });

        balanceOf.mint({ receiver: receiver, id: currency.toId(), amount: protocolFee });
        amountCharged += protocolFee;
        currency.transferOrApprove(claim.account, amountCharged);

        emit PerUseSettled({
            account: claim.account,
            module: msg.sender,
            amountCharged: amountCharged
        });
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
