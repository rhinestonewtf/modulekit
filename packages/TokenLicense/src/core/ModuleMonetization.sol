// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GasliteSplitterFactory } from "../splitter/Factory.sol";
import { GasliteSplitter } from "../splitter/Splitter.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";
import { SplitterConf } from "./SplitterConf.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { SignatureCheckerLib } from "solady/src/utils/SignatureCheckerLib.sol";
import { EIP712 } from "solady/src/utils/EIP712.sol";
import { ILicenseManager } from "../interfaces/ILicenseManager.sol";
import { IERC2612 } from "@openzeppelin/contracts/interfaces/IERC2612.sol";
import { IPermit2 } from "permit2/src/interfaces/IPermit2.sol";

import "../DataTypes.sol";

abstract contract ModuleMonetization is ILicenseManager, EIP712, Ownable {
    using SignatureCheckerLib for address;

    address internal immutable TOKEN;
    address internal txFeeSessionKey;
    address internal subscriptionSessionKey;
    IPermit2 internal immutable PERMIT2;
    GasliteSplitterFactory public immutable SPLITTER_FACTORY;
    SplitterConf internal immutable SPLITTER_CONF;
    uint256 constant MAX_PERCENTAGE = 10;

    mapping(address module => ModuleMoneyConf conf) internal _moduleMoneyConfs;
    mapping(address module => uint256 nonce) internal _moduleNonces;

    constructor(IPermit2 permit2, address token, SplitterConf splitterConf) EIP712() {
        TOKEN = token;
        PERMIT2 = permit2;
        SPLITTER_CONF = splitterConf;
        SPLITTER_FACTORY = new GasliteSplitterFactory();
        _initializeOwner(msg.sender);
    }

    function _iterNonce(address module) internal returns (uint256 nonce) {
        nonce = _moduleNonces[module] + 1;
        _moduleNonces[module] = nonce;
        nonce = uint256(bytes32(keccak256(abi.encodePacked(module, nonce))));
    }

    modifier onlyRegistry() {
        // TODO
        _;
    }

    modifier onlyModuleOwner(address module) {
        if (_moduleMoneyConfs[module].owner != msg.sender) revert UnauthorizedModuleOwner();
        _;
    }

    function transferOwner(address module, address newOwner) external onlyModuleOwner(module) {
        _moduleMoneyConfs[module].owner = newOwner;
        emit NewModuleOwner(module, newOwner);
    }

    function initialize(address _txFeeSigner, address _subscriptionSigner) external onlyOwner {
        txFeeSessionKey = _txFeeSigner;
        subscriptionSessionKey = _subscriptionSigner;
    }

    function updateModuleMonetization(
        address module,
        uint128 pricePerSecond,
        uint32 txPercentage
    )
        external
        override
        onlyModuleOwner(module)
    {
        _moduleMoneyConfs[module].pricePerSecond = pricePerSecond;
        _moduleMoneyConfs[module].txPercentage = txPercentage;
        emit NewModuleMonetization(module);
    }

    function updateSplitter(
        address module,
        bytes[] calldata signatures,
        address[] calldata newRecipients,
        uint256[] calldata newShares
    )
        external
        onlyOwner
    {
        address[] memory recipients =
            GasliteSplitter(payable(_moduleMoneyConfs[module].splitter)).recipients();

        // could build a mechanism here, that if equities stay the same,
        // and only the shareholder
        // wants to key rotate, he can

        uint256 lengthSignatures = signatures.length;
        require(lengthSignatures == recipients.length, "invalid signatures");

        for (uint256 i = 0; i < lengthSignatures; i++) {
            bytes32 hash = keccak256(abi.encodePacked(module)); // todo
            bytes calldata signature = signatures[i];
            address signer = recipients[i];

            bool valid =
                signer.isValidSignatureNowCalldata(ECDSA.toEthSignedMessageHash(hash), signature);
            require(valid, "invalid signature");
        }

        _setSplitter(module, newRecipients, newShares);
    }

    function resolveModuleRegistration(
        address, /*dev*/
        address moduleRecord,
        bytes calldata data
    )
        external
        onlyRegistry
        returns (bool)
    {
        address moduleDevBeneficiary = abi.decode(data, (address));

        address[] memory recipients = new address[](2);
        recipients[0] = moduleDevBeneficiary;
        recipients[1] = owner();

        uint256[] memory shares = SPLITTER_CONF.getEquity(moduleRecord);
        require(shares.length == 2, "invalid equity");

        // TODO check upper bound for shares. owner should not be able to claim a huge amounts of
        // equity

        _setSplitter(moduleRecord, recipients, shares);

        return true;
    }

    function withdraw(address module) external {
        GasliteSplitter(payable(_moduleMoneyConfs[module].splitter)).release(address(TOKEN));
    }

    function killMonetization(address module) external onlyOwner {
        delete _moduleMoneyConfs[module].owner;
        delete _moduleMoneyConfs[module].splitter;
        delete _moduleMoneyConfs[module].pricePerSecond;
        delete _moduleMoneyConfs[module].txPercentage;
    }

    function moduleRegistration(
        address moduleRecord,
        address moduleDevBeneficiary
    )
        external
        onlyOwner
    {
        address[] memory recipients = new address[](2);
        recipients[0] = moduleDevBeneficiary;
        recipients[1] = owner();

        uint256[] memory shares = SPLITTER_CONF.getEquity(moduleRecord);
        require(shares.length == 2, "invalid equity");

        // TODO check upper bound for shares

        _setSplitter(moduleRecord, recipients, shares);
    }

    function _setSplitter(
        address module,
        address[] memory recipients,
        uint256[] memory shares
    )
        internal
    {
        address splitter = SPLITTER_FACTORY.findDeploymentAddress(
            recipients, shares, false, keccak256(abi.encodePacked(module))
        );
        _moduleMoneyConfs[module].splitter = splitter;
        emit NewSplitter(module, splitter);
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
