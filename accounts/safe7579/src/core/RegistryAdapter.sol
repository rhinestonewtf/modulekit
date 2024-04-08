// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IERC7484.sol";

contract RegistryAdapter {
    event ERC7484RegistryConfigured(address indexed smartAccount, address indexed registry);

    mapping(address smartAccount => IERC7484 registry) internal $registry;

    modifier withRegistry(address module, uint256 moduleType) {
        IERC7484 registry = $registry[msg.sender];
        if (address(registry) != address(0)) {
            registry.check(module, moduleType);
        }
        _;
    }

    function _configureRegistry(
        IERC7484 registry,
        address[] calldata attesters,
        uint8 threshold
    )
        internal
    {
        $registry[msg.sender] = registry;
        registry.trustAttesters(threshold, attesters);
    }
}
