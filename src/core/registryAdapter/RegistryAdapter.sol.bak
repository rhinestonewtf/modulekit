// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC7484Registry } from "../../common/IERC7484.sol";
/// @title RegistryAdapter
/// @author zeroknots

abstract contract RegistryAdapterForSingletons {
    // Instance of the IRegistry contract
    IERC7484Registry immutable registry;

    // Address of the trusted authority
    address trustedAuthority;

    mapping(address account => address trustedAttester) internal trustedAttester;

    constructor(IERC7484Registry _registry) {
        registry = _registry;
    }

    function _setAttester(address account, address attester) internal {
        trustedAttester[account] = attester;
    }

    function _enforceRegistryCheck(address executorImpl) internal view virtual {
        registry.check(executorImpl, trustedAttester[msg.sender]);
    }
}
