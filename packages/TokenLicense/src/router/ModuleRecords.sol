// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";
import { IPermit2, ISignatureTransfer } from "permit2/src/interfaces/IPermit2.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";
import { EIP712 } from "solady/src/utils/EIP712.sol";
import "../splitter/IShareholder.sol";

abstract contract ModuleRecords is Ownable, EIP712 {
    IPermit2 internal immutable PERMIT2;

    address internal SIGNER_TX_SELF;
    address internal SIGNER_TX_SPONSOR;
    address internal SIGNER_SUB_SELF;
    address internal SIGNER_SUB_SPONSOR;

    mapping(address module => uint256 nonce) internal _moduleNonces;
    mapping(address module => IShareholder shareholder) internal $moduleShareholders;

    constructor(IPermit2 permit2) EIP712() {
        PERMIT2 = permit2;
        _initializeOwner(msg.sender);
    }

    function _iterModuleNonce(address module) internal returns (uint256 nonce) {
        nonce = _moduleNonces[module] + 1;
        _moduleNonces[module] = nonce;
        nonce = uint256(bytes32(keccak256(abi.encodePacked(module, nonce))));
    }

    function initSigners(
        address signerTxSelf,
        address signerTxSponsor,
        address signerSubSelf,
        address signerSubSponsor
    )
        external
        onlyOwner
    {
        SIGNER_TX_SELF = signerTxSelf;
        SIGNER_TX_SPONSOR = signerTxSponsor;
        SIGNER_SUB_SELF = signerSubSelf;
        SIGNER_SUB_SPONSOR = signerSubSponsor;
    }

    function registerShareholder(address module, IShareholder shareholder) external onlyOwner {
        $moduleShareholders[module] = shareholder;
    }

    function _domainNameAndVersion()
        internal
        view
        virtual
        override
        returns (string memory name, string memory version)
    {
        name = "LicenseManager";
        version = "0.0.1";
    }

    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }
}
