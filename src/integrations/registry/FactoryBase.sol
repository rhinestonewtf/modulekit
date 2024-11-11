// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { IERC7484 } from "src/Interfaces.sol";

abstract contract FactoryBase {
    IERC7484 public immutable REGISTRY;

    address[] public trustedAttesters;
    uint8 public threshold;

    constructor(address _registry, address[] memory _trustedAttesters, uint8 _threshold) {
        REGISTRY = IERC7484(_registry);
        trustedAttesters = _trustedAttesters;
        threshold = _threshold;
    }

    function _checkRegistry(address module, uint256 moduleType) internal {
        REGISTRY.check(module, moduleType, trustedAttesters, threshold);
    }
}
