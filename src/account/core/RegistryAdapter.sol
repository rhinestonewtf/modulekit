// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRSQuery} from "../interfaces/IRSQuery.sol";
/// @title RegistryAdapter
/// @author zeroknots

abstract contract RegistryAdapter {
    // Instance of the IRSQuery contract
    IRSQuery registry;

    // Address of the trusted authority
    address trustedAuthority;

    error PluginNotPermitted(address plugin, uint48 listedAt, uint48 flaggedAt);

    function _initializeRegistryAdapter(address _registry, address _trustedAuthority) internal {
        registry = IRSQuery(_registry);
        trustedAuthority = _trustedAuthority;
    }

    function _enforceRegistryCheck(address pluginImpl) internal view virtual {
        (uint48 listedAt, uint48 flaggedAt) = registry.check(pluginImpl, trustedAuthority);

        // revert if plugin was ever flagged or was never attested to
        if (listedAt == 0 || flaggedAt != 0) {
            revert PluginNotPermitted(pluginImpl, listedAt, flaggedAt);
        }
    }
}
