// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC7484Registry {
    function check(address executor, address attester) external view returns (uint256 listedAt);

    function checkN(
        address module,
        address[] memory attesters,
        uint256 threshold
    )
        external
        view
        returns (uint256[] memory attestedAtArray);
}

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

    modifier onlySecureModule(address module) {
        _enforceRegistryCheck(module);
        _;
    }

    function _setAttester(address account, address attester) internal {
        trustedAttester[account] = attester;
    }

    function _enforceRegistryCheck(address executorImpl) internal view virtual {
        registry.check(executorImpl, trustedAttester[msg.sender]);
    }
}
