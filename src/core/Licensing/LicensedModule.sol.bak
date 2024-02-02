// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ILicensedModule } from "./LicenseManager.sol";
import { ERC7579ExecutorBase } from "../../modules/ERC7579ExecutorBase.sol";

contract LicensedModule is ILicensedModule, ERC7579ExecutorBase {
    address manager;
    address immutable licenseToken;

    struct License {
        uint128 amount;
        uint48 timestamp;
    }

    mapping(address smartAccount => License license) _fees;

    constructor(address _manager, address _token) {
        manager = _manager;
        licenseToken = _token;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "only manager");
        _;
    }

    modifier subscribeLicense() {
        _fees[msg.sender].timestamp = uint48(block.timestamp);
        _;
    }

    modifier unsubscribeLicense() {
        _fees[msg.sender].timestamp = 0;
        _;
    }

    function _addAmount(address account, uint128 addAmount) internal {
        _fees[account].amount += addAmount;
    }

    function calcFee(address account, address token) external view returns (uint256 amount) {
        License storage license = _fees[account];
        if (license.timestamp == 0) {
            return 0;
        }
        if (token != licenseToken) {
            return 0;
        }
        amount = license.amount;
    }

    function deductFee(
        address account,
        address token
    )
        external
        override
        onlyManager
        returns (uint256 amount)
    {
        License storage license = _fees[account];
        if (license.timestamp == 0) {
            return 0;
        }
        if (token != licenseToken) {
            return 0;
        }
        amount = license.amount;
        license.amount = 0;
        license.timestamp = uint48(block.timestamp);
    }

    function name() external pure virtual override returns (string memory) {
        return "Lic Module";
    }

    function version() external pure virtual override returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 _type) external pure virtual override returns (bool) {
        return _type == TYPE_VALIDATOR;
    }

    function onInstall(bytes calldata data) external override subscribeLicense {
        _addAmount(msg.sender, 10 ether);
    }

    function onUninstall(bytes calldata data) external override unsubscribeLicense { }
}
