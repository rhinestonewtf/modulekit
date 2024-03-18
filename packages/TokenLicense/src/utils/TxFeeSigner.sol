// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import "./LicenseSignerBase.sol";
import "../interfaces/IERC1271.sol";
import { LicenseHash } from "../lib/LicenseHash.sol";
import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";
import "forge-std/console2.sol";

contract TxFeeSigner is LicenseSignerBase {
    using EIP712Signer for bytes32;
    using EIP712Signer for ISignatureTransfer.PermitTransferFrom;
    using LicenseHash for LicenseManagerTxFee;

    mapping(address smartAccount => mapping(address module => bool enabledTxFee)) internal _txFee;

    constructor(
        address permit2,
        address licenseManager
    )
        LicenseSignerBase(permit2, licenseManager)
    { }

    function configure(address module, bool enabled) external {
        _txFee[msg.sender][module] = enabled;
    }

    function isModulePaymentEnabled(
        address smartAccount,
        address module
    )
        public
        view
        returns (bool)
    {
        return _txFee[smartAccount][module];
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
        (ISignatureTransfer.PermitTransferFrom memory permit, LicenseManagerTxFee memory txFee) =
            abi.decode(encodedTxFee, (ISignatureTransfer.PermitTransferFrom, LicenseManagerTxFee));
        bytes32 witness = LICENSE_MANAGER_DOMAIN_SEPARATOR.hashTypedData(txFee.hash());
        bytes32 permitHash =
            permit.hashWithWitness(address(LICENSE_MANAGER), witness, TX_FEE_WITNESS);
        bytes32 expected1271Hash = PERMIT2_DOMAIN_SEPARATOR.hashTypedData(permitHash);

        if (!isModulePaymentEnabled(msg.sender, txFee.module)) return 0xFFFFFFFF;

        if (expected1271Hash == hash) {
            return IERC1271.isValidSignature.selector;
        }
    }
}
