// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRegistry} from "../../auxiliary/interfaces/IRegistry.sol";
/// @title RegistryAdapter
/// @author zeroknots

abstract contract RegistryAdapter {
    // Instance of the IRegistry contract
    IRegistry registry;

    // Address of the trusted authority
    address trustedAuthority;

    error ExecutorNotPermitted(address executor, uint48 listedAt, uint48 flaggedAt);

    mapping(address account => address trustedAttester) internal trustedAttester;

    function _setRegistry(address _registry) internal {
        registry = IRegistry(_registry);
    }

    function _setAttester(address account, address attester) internal {
        trustedAttester[account] = attester;
    }

    function _enforceRegistryCheck(address executorImpl) internal view virtual {
        (uint48 listedAt, uint48 flaggedAt) = registry.check(executorImpl, trustedAttester[msg.sender]);

        // revert if executor was ever flagged or was never attested to
        if (listedAt == 0 || flaggedAt != 0) {
            revert ExecutorNotPermitted(executorImpl, listedAt, flaggedAt);
        }
    }
}
