// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IDistributor.sol";
import { LicenseRegistry } from "./LicenseRegistry.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";
import "../splitter/Factory.sol";

contract Distributor is Ownable, IDistributor, LicenseRegistry {
    using SafeTransferLib for address;

    error UnauthorizedModuleOwner();

    address immutable TOKEN;
    GasliteSplitterFactory public splitterFactory;

    mapping(address module => ModuleMonetization) internal _moduleMonetizations;

    constructor(address token) {
        _initializeOwner(msg.sender);
        TOKEN = token;
        splitterFactory = new GasliteSplitterFactory();
    }

    function underlyingToken() external view override returns (address) {
        return TOKEN;
    }

    modifier onlyModuleOwner(address module) {
        if (_moduleMonetizations[module].owner != msg.sender) revert UnauthorizedModuleOwner();
        _;
    }

    modifier onlyRegistry() {
        // TODO
        _;
    }

    function distribute(FeeDistribution calldata distro) external override {
        // how many seconds does the amount cover?
        uint256 secondsCovered = distro.amount / _moduleMonetizations[distro.module].pricePerSecond;
        uint256 validUntil = _accountLicenses[distro.module][msg.sender].validUntil;
        uint48 newValidUntil = (validUntil == 0)
            ? uint48(block.timestamp + secondsCovered)
            : uint48(validUntil + secondsCovered);
        _accountLicenses[distro.module][msg.sender].validUntil = uint48(newValidUntil);

        TOKEN.safeTransferFrom(
            msg.sender, _moduleMonetizations[distro.module].beneficiary, distro.amount
        );
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
        ModuleMonetization memory mm = abi.decode(data, (ModuleMonetization));

        address[] memory recipients = new address[](2);
        recipients[0] = mm.beneficiary;
        recipients[1] = owner();

        uint256[] memory shares = new uint256[](2);
        shares[0] = 90;
        shares[1] = 10;

        address splitter = splitterFactory.findDeploymentAddress(
            recipients, shares, false, keccak256(abi.encodePacked(moduleRecord))
        );
        mm.beneficiary = splitter;

        _moduleMonetizations[moduleRecord] = mm;
        return true;
    }

    function updateModuleMonetization(
        address module,
        uint128 pricePerSecond
    )
        external
        onlyModuleOwner(module)
    {
        _moduleMonetizations[module].pricePerSecond = pricePerSecond;
    }
}
