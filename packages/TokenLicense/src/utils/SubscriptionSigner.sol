// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import "./LicenseSignerBase.sol";
import "../interfaces/IERC1271.sol";
import { LicenseHash } from "../lib/LicenseHash.sol";
import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";
import "forge-std/console2.sol";

contract SubscriptionSigner is LicenseSignerBase {
    using EIP712Signer for bytes32;
    using EIP712Signer for ISignatureTransfer.PermitTransferFrom;
    using LicenseHash for LicenseManagerSubscription;

    mapping(address smartAccount => mapping(address module => bool enabledSubscription)) internal
        _subscriptions;

    constructor(
        address permit2,
        address licenseManager
    )
        LicenseSignerBase(permit2, licenseManager)
    { }

    function configure(address module, bool enabled) external {
        _subscriptions[msg.sender][module] = enabled;
    }

    function isModulePaymentEnabled(
        address smartAccount,
        address module
    )
        public
        view
        returns (bool)
    {
        return _subscriptions[smartAccount][module];
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata encodedTxFee // DataTYpes.LcienseManagerTxFee
    )
        external
        view
        virtual
        override
        onlyPermit2(sender)
        returns (bytes4 magicValue)
    {
        (
            ISignatureTransfer.PermitTransferFrom memory permit,
            LicenseManagerSubscription memory subscription
        ) = abi.decode(
            encodedTxFee, (ISignatureTransfer.PermitTransferFrom, LicenseManagerSubscription)
        );
        bytes32 witness = LICENSE_MANAGER_DOMAIN_SEPARATOR.hashTypedData(subscription.hash());
        bytes32 permitHash =
            permit.hashWithWitness(address(LICENSE_MANAGER), witness, SUBSCRIPTION_WITNESS);
        bytes32 expected1271Hash = PERMIT2_DOMAIN_SEPARATOR.hashTypedData(permitHash);

        if (!isModulePaymentEnabled(msg.sender, subscription.module)) return 0xFFFFFFFF;

        if (expected1271Hash == hash) {
            return IERC1271.isValidSignature.selector;
        }
    }
}
