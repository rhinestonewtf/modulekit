// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import "./LicenseSignerBase.sol";
import "../interfaces/IERC1271.sol";
import { LicenseHash } from "../lib/LicenseHash.sol";
import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import { PermitHash } from "permit2/src/libraries/PermitHash.sol";
import "forge-std/console2.sol";

contract MultiSigner is LicenseSignerBase {
    using EIP712Signer for bytes32;
    using EIP712Signer for ISignatureTransfer.PermitTransferFrom;
    using EIP712Signer for ISignatureTransfer.PermitBatchTransferFrom;
    using LicenseHash for *;

    error InvalidInput();

    struct FeePermissions {
        bool enabled;
        uint128 usdAmountMax;
    }

    struct AccountConfig {
        mapping(ClaimType claimType => FeePermissions permissions) _selfConfigs;
        mapping(
            address licensee => mapping(ClaimType claimType => FeePermissions sponsoredPermissions)
            ) _sponsorConfigs;
    }

    mapping(address smartAccount => mapping(address module => AccountConfig conf)) internal
        _accountConfigs;

    constructor(
        address permit2,
        address licenseManager
    )
        LicenseSignerBase(permit2, licenseManager)
    { }

    function configureSelfPay(
        address module,
        ClaimType[] calldata claimTypes,
        FeePermissions[] calldata permissions
    )
        external
    {
        uint256 length = permissions.length;
        if (claimTypes.length != length) revert InvalidInput();

        AccountConfig storage $conf = _accountConfigs[msg.sender][module];
        for (uint256 i; i < length; i++) {
            $conf._selfConfigs[claimTypes[i]] = permissions[i];
        }
    }

    function configureSonsorPay(
        address module,
        address licensee,
        ClaimType[] calldata claimTypes,
        FeePermissions[] calldata permissions
    )
        external
    {
        uint256 length = permissions.length;
        if (claimTypes.length != length) revert InvalidInput();

        AccountConfig storage $conf = _accountConfigs[msg.sender][module];
        for (uint256 i; i < length; i++) {
            $conf._sponsorConfigs[licensee][claimTypes[i]] = permissions[i];
        }
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata claimData
    )
        external
        view
        virtual
        override
        onlyPermit2(sender)
        returns (bytes4 magicValue)
    {
        (ISignatureTransfer.PermitBatchTransferFrom memory permit, Claim memory claim) =
            abi.decode(claimData, (ISignatureTransfer.PermitBatchTransferFrom, Claim));
        bytes32 witness = LICENSE_MANAGER_DOMAIN_SEPARATOR.hashTypedData(claim.hash());
        bytes32 permitHash = permit.hashWithWitness(address(LICENSE_MANAGER), witness, CLAIM_STRING);
        bytes32 expected1271Hash = PERMIT2_DOMAIN_SEPARATOR.hashTypedData(permitHash);

        if (expected1271Hash != hash) {
            return 0x00000000;
        }

        AccountConfig storage $conf = _accountConfigs[msg.sender][claim.module];
        // self pay
        if (claim.smartAccount == msg.sender) {
            FeePermissions storage $permissions = $conf._selfConfigs[claim.claimType];
            if ($permissions.enabled && claim.usdAmount <= $permissions.usdAmountMax) {
                return IERC1271.isValidSignature.selector;
            }
        }
        // sponsored pay
        else {
            FeePermissions storage $permissions =
                $conf._sponsorConfigs[claim.smartAccount][claim.claimType];
            if ($permissions.enabled && claim.usdAmount <= $permissions.usdAmountMax) {
                return IERC1271.isValidSignature.selector;
            }
        }
    }
}
