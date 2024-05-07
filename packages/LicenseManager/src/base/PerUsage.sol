// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../DataTypes.sol";

abstract contract PerUsage {
    mapping(address module => PerUseRecord record) public $perUseRecord;

    // TODO: access control
    function setPerUsageConfig(address module, Currency currency, uint128 pricePerUsage) external {
        $perUseRecord[module] = PerUseRecord({ currency: currency, pricePerUsage: pricePerUsage });
    }
}
