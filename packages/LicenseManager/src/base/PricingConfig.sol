// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import "../interfaces/IFeeMachine.sol";
import "../ILicenseManager.sol";
import "./ModuleRegister.sol";

abstract contract PricingConfig is ILicenseManager, ModuleRegister {
    error UnauthorizedModuleAuthority();

    event NewModuleAuthority(address oldAuthority, address newAuthority);
    event UpdatedModuleSubscription(address module, PricingSubscription subscription);
    event UpdatedModulePerUse(address module, PricingPerUse subscription);
    event UpdatedModuleTransactionFee(address module, PricingTransaction transaction);

    modifier onlyModuleAuthority(address module) {
        if (msg.sender != $module[module].authority) revert UnauthorizedModuleAuthority();
        _;
    }

    function transferModuleAuthority(
        address module,
        address newAuthority
    )
        external
        onlyModuleAuthority(module)
    {
        $module[module].authority = newAuthority;
        emit NewModuleAuthority(msg.sender, newAuthority);
    }

    function setSubscription(
        address module,
        PricingSubscription calldata subscription
    )
        external
        onlyModuleAuthority(module)
    {
        ModuleRecord storage $moduleRecord = $module[module];

        $moduleRecord.subscription = subscription;

        emit UpdatedModuleSubscription(module, subscription);
    }

    function setPerUse(
        address module,
        PricingPerUse calldata perUse
    )
        external
        onlyModuleAuthority(module)
    {
        ModuleRecord storage $moduleRecord = $module[module];

        $moduleRecord.perUse = perUse;
    }

    function setTransaction(
        address module,
        PricingTransaction calldata transaction
    )
        external
        onlyModuleAuthority(module)
    {
        ModuleRecord storage $moduleRecord = $module[module];
        $moduleRecord.transaction = transaction;

        emit UpdatedModuleTransactionFee(module, transaction);
    }
}
