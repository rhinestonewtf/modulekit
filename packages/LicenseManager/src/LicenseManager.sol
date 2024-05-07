// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./base/ERC6909.sol";
import "./base/Protocol.sol";
import "./base/PerUsage.sol";
import "./base/ModulesRegister.sol";
import "./lib/Currency.sol";
import "./interfaces/ILicenseManager.sol";
import "./interfaces/IFeeMachine.sol";
import "./base/Subscription.sol";

import "forge-std/console2.sol";

contract LicenseManager is
    ILicenseManager,
    Protocol,
    Subscription,
    ModulesRegister,
    PerUsage,
    ERC6909
{
    using CurrencyLibrary for Currency;

    error UnauthorizedModule();
    error InvalidClaim();

    constructor(IProtocolController controller) {
        _initializeOwner(address(controller));
    }

    function settleTransaction(ClaimTransaction calldata claim)
        public
        returns (bool success, uint256 totalAfterFee)
    {
        ModuleFee memory moduleFee = $moduleFees[msg.sender];
        if (moduleFee.enabled == false) return (false, 0);

        Split[] memory split = moduleFee.feeMachine.split({ module: msg.sender, claim: claim });
        uint256 total = _mint(claim.currency, split);
        if (total == 0) return (true, claim.amount);

        uint256 protocolFee;
        address beneficiary;
        (protocolFee, total, beneficiary) = addProtocolFee({
            account: claim.account,
            currency: claim.currency,
            module: msg.sender,
            feeMachine: moduleFee.feeMachine,
            claimType: ClaimType.Transaction,
            total: total
        });

        _mint({ receiver: beneficiary, id: claim.currency.toId(), amount: protocolFee });

        console2.log("transfer", claim.account, total, Currency.unwrap(claim.currency));
        claim.currency.transferOrApprove(claim.account, total);

        emit TransactionSettled({ account: claim.account, module: msg.sender, amountCharged: total });

        return (true, claim.amount - total);
    }

    function settleSubscription(ClaimSubscription calldata claim)
        external
        returns (bool success, uint256 total)
    {
        address account = claim.account;
        address module = claim.module;
        SubscriptionRecord storage $license = $activeLicenses[module][account];
        SubscriptionPricing memory subscriptionRecord = $moduleSubPricing[module];
        ModuleFee memory moduleFee = $moduleFees[module];

        if (moduleFee.enabled == false) return (false, 0);

        $license.validUntil =
            _validUntil({ smartAccount: account, module: module, amount: claim.amount });
        Split[] memory split = moduleFee.feeMachine.split({ claim: claim });
        total = _mint(subscriptionRecord.currency, split);
        if (total == 0) return (true, 0);

        uint256 protocolFee;
        address beneficiary;
        (protocolFee, total, beneficiary) = addProtocolFee({
            account: account,
            module: msg.sender,
            currency: subscriptionRecord.currency,
            feeMachine: moduleFee.feeMachine,
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
        returns (bool success, uint256 total)
    {
        address account = claim.account;
        address module = msg.sender;

        ModuleFee memory moduleFee = $moduleFees[module];
        PerUseRecord memory perUseRecord = $perUseRecord[module];

        Split[] memory split = moduleFee.feeMachine.split({ claim: claim });
        total = _mint(perUseRecord.currency, split);

        uint256 protocolFee;
        address beneficiary;
        (protocolFee, total, beneficiary) = addProtocolFee({
            account: account,
            module: msg.sender,
            currency: perUseRecord.currency,
            feeMachine: moduleFee.feeMachine,
            claimType: ClaimType.Transaction,
            total: total
        });

        _mint({ receiver: beneficiary, id: perUseRecord.currency.toId(), amount: protocolFee });
        perUseRecord.currency.transferFrom(account, total);

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
            address beneficiary = splits[i].beneficiary;
            uint256 amount = splits[i].amount;
            total += amount;
            _mint({ receiver: beneficiary, id: id, amount: amount });
        }
    }
}
