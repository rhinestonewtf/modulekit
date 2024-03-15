// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";
import "permit2/src/interfaces/IPermit2.sol";
import "forge-std/console2.sol";

contract LicenseRouter is Ownable {
    using SafeTransferLib for address;

    IPermit2 internal immutable PERMIT2;
    address internal immutable REGISTRY;

    event LicenseUpdate(address indexed module, address indexed account, uint48 expiration);
    event Blacklist(address indexed account, bool isBlacklisted);
    event NewBeneficiary(address indexed module, address indexed newBeneficiary);

    error Blacklisted(address account);
    error NotTransferable(address module);
    error NoActiveLicense(address account, address module);
    error InvalidModule(address module);

    address public immutable PAYMENT_TOKEN;

    struct Subscription {
        uint48 validUntil;
    }

    struct ModuleLicense {
        bool isTransferable;
        uint48 renewals;
        address beneficiary;
        uint256 price;
        uint16 txPercentage;
    }

    mapping(address module => mapping(address account => Subscription moduleLicense)) internal
        _licenses;
    mapping(address module => ModuleLicense modulePrices) internal _modules;

    mapping(address account => bool blacklisted) internal _blacklist;

    constructor(address _paymentToken, address _permit2, address _registry) {
        initialize(msg.sender);
        PERMIT2 = IPermit2(_permit2);
        REGISTRY = _registry;
        PAYMENT_TOKEN = _paymentToken;
    }

    function initialize(address owner) public {
        _initializeOwner(owner);
    }

    modifier onlyTransferable(address module) {
        if (_modules[module].isTransferable == false) revert NotTransferable(module);
        _;
    }

    modifier forModule(address module) {
        if (_modules[msg.sender].beneficiary == address(0)) revert InvalidModule(module);
        _;
    }

    modifier notBlacklisted(address account) {
        if (_blacklist[account]) revert Blacklisted(account);
        _;
    }

    // TODO: add actual registry hook
    function registerModule(address module, ModuleLicense calldata moduleLicense) external {
        require(msg.sender == REGISTRY, "LicenseRouter: Unauthorized");
        _modules[module] = moduleLicense;
    }

    function updateBeneficiary(address module, address newBeneficiary) external {
        if (_modules[module].beneficiary != msg.sender) revert Unauthorized();
        _modules[module].beneficiary = newBeneficiary;
        emit NewBeneficiary(module, newBeneficiary);
    }

    function blacklist(address account) external onlyOwner {
        bool isBlacklisted = _blacklist[account];
        _blacklist[account] = !isBlacklisted;

        emit Blacklist(account, isBlacklisted);
    }

    function setModule(address module, ModuleLicense calldata moduleLicense) external onlyOwner {
        _modules[module] = moduleLicense;
    }

    function burnLicense(address account, address module) public forModule(module) onlyOwner {
        _licenses[module][account].validUntil = 0;
        emit LicenseUpdate(module, account, 0);
    }

    function burnLicense(address module) public forModule(module) {
        _licenses[module][msg.sender].validUntil = 0;
        emit LicenseUpdate(module, msg.sender, 0);
    }

    function mintLicense(address account, address module) public notBlacklisted(account) {
        ModuleLicense memory moduleLicense = _modules[module];
        Subscription memory subscription = _licenses[module][account];

        if (moduleLicense.beneficiary == address(0)) revert InvalidModule(module);

        uint48 _validUntil = (subscription.validUntil == 0)
            ? uint48(block.timestamp + moduleLicense.renewals)
            : uint48(subscription.validUntil + moduleLicense.renewals);

        _licenses[module][account].validUntil += _validUntil;
        PAYMENT_TOKEN.safeTransferFrom(
            account, address(moduleLicense.beneficiary), moduleLicense.price
        );

        emit LicenseUpdate(module, account, _validUntil);
    }

    function mintLicense(
        address account,
        address module,
        bytes calldata permit2Signature
    )
        external
        forModule(module)
    {
        ModuleLicense memory moduleLicense = _modules[module];
        Subscription memory subscription = _licenses[module][account];

        IPermit2.TokenPermissions memory tokenPermissions = ISignatureTransfer.TokenPermissions({
            token: PAYMENT_TOKEN,
            amount: moduleLicense.price
        });
        console2.log("tokenPermissions", tokenPermissions.token, tokenPermissions.amount);

        IPermit2.PermitTransferFrom memory permitTransferFrom = ISignatureTransfer
            .PermitTransferFrom({
            permitted: tokenPermissions,
            nonce: 123_123,
            deadline: block.timestamp + 1 days
        });

        IPermit2.SignatureTransferDetails memory transferDetails = ISignatureTransfer
            .SignatureTransferDetails({
            to: moduleLicense.beneficiary,
            requestedAmount: permitTransferFrom.permitted.amount
        });

        uint48 _validUntil = (subscription.validUntil == 0)
            ? uint48(block.timestamp + moduleLicense.renewals)
            : uint48(subscription.validUntil + moduleLicense.renewals);

        _licenses[module][account].validUntil += _validUntil;
        console2.logBytes(permit2Signature);

        PERMIT2.permitTransferFrom({
            permit: permitTransferFrom,
            transferDetails: transferDetails,
            owner: account,
            signature: permit2Signature
        });

        emit LicenseUpdate(module, account, _validUntil);
    }

    function txFee(address account, uint256 processedAmount) external {
        uint256 txPercentage = _modules[msg.sender].txPercentage;
        uint256 amount = processedAmount * txPercentage / 1e6;
        PAYMENT_TOKEN.safeTransferFrom(account, _modules[msg.sender].beneficiary, amount);
    }

    function validUntil(address account, address module) public view returns (uint48) {
        return _licenses[module][account].validUntil;
    }

    function hasActiveLicenses(address account, address module) public view returns (bool) {
        return _licenses[module][account].validUntil > block.timestamp;
    }

    function transferLicense(
        address to,
        address module
    )
        external
        notBlacklisted(msg.sender)
        onlyTransferable(module)
    {
        Subscription memory license = _licenses[module][msg.sender];
        if (!hasActiveLicenses(msg.sender, module)) revert NoActiveLicense(msg.sender, module);

        _licenses[module][msg.sender].validUntil = 0;
        _licenses[module][to].validUntil = license.validUntil;
        emit LicenseUpdate(module, msg.sender, 0);
        emit LicenseUpdate(module, to, license.validUntil);
    }
}
