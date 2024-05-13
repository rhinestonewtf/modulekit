// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./lib/Currency.sol";
import "./DataTypes.sol";
import "./subscription/ISubscription.sol";

interface ILicenseManager {
    event TransactionSettled(address account, address module, uint256 amountCharged);
    event SubscriptionSettled(address account, address module, uint256 amountCharged);
    event PerUseSettled(address account, address module, uint256 amountCharged);

    error SubscriptionTooShort();

    /**
     * Allows Modules to Claim transaction fees during Module Execution.
     * msg.sender is expected to be the Module itself.
     * License Manager will call IFeeMachine set for the Module (msg.sender) and calculate the
     * amount to be charged.
     * @param claim Transaction Claim for module
     * @return amountCharged the amount charged in the ERC20 token that was provided in the Claim
     */
    function settleTransaction(ClaimTransaction calldata claim)
        external
        returns (uint256 amountCharged);

    /**
     * Allows SmartAccounts to make/renew a Subscription of a Module
     * msg.sender is expected to be the Payer of the subscription.
     * The recipient of the subscription license (contained in ClaimSubscription struct) may differ.
     * License Manager will call IFeeMachine set for the Module (msg.sender) and calculate the
     * amount to be charged.
     * @param claim Subscription Claim for module
     * @return amountCharged the amount charged in the ERC20 token that is used as the base
     * Currency of subscription
     */
    function settleSubscription(ClaimSubscription calldata claim)
        external
        returns (uint256 amountCharged);

    /**
     * Returns if account currenty has a valid subscription for the module. License manager is not
     * storing the subscription token itself, but is using a deployed
     * ./subscription/Subscription.sol. It is forwarding the calls to the Subscription contract.
     */
    function isActiveSubscription(address account, address module) external view returns (bool);

    /**
     * Returns timestamp of account's subscription for the module. This will be 0 if no license was
     * ever aquired. License manager is not
     * storing the subscription token itself, but is using a deployed
     * ./subscription/Subscription.sol. It is forwarding the calls to the Subscription contract.
     */
    function getSubscription(address account, address module) external view returns (uint256);
    /**
     * Allows Module to Claim per Usage fees during Module Execution
     * msg.sender is expected to be the Module itself.
     * License Manager will call IFeeMachine set for the Module (msg.sender) and calculate the
     * amount to be charged.
     * @param claim Subscription Claim for module
     * @return amountCharged the amount charged in the ERC20 token that is used as the Base
     * Currency for Usage Licenses
     */
    function settlePerUsage(ClaimPerUse calldata claim) external returns (uint256 amountCharged);

    /**
     * Allows FeeMachines to register a Module on the LicenseManager.
     * This Function will revert if the module is already registered or msg.sender is not an
     * authorized FeeMachine
     */
    function enableModule(address module, address authority, bool enabled) external;

    /**
     * Allows ProtocolController to authorize a FeeMachine.
     */
    function authorizeFeeMachine(IFeeMachine feeMachine, bool enabled) external;

    /**
     * Allows Developer / Authority of a Module to transfer the Authority of the Module to a new
     * address
     */
    function transferModuleAuthority(address module, address newAuthority) external;

    /**
     * Allows Developer / Authority of a Module to set the Subscription Pricing for the Module
     */
    function setSubscription(address module, PricingSubscription calldata subscription) external;

    /**
     * Allows Developer / Authority of a Module to set the PerUsage Pricing for the Module
     */
    function setPerUse(address module, PricingPerUse calldata perUse) external;

    /**
     * Allows Developer / Authority of a Module to set the Transaction Pricing for the Module
     */
    function setTransaction(address module, PricingTransaction calldata transaction) external;

    /**
     * LicenseManager uses ISubscription Token to manage active subscriptions.
     *  This component is an external contract, to allow for upgradability to subscription logic,
     * without making LicenseManager upgradable.
     */
    function subtoken() external view returns (ISubscription);
}
