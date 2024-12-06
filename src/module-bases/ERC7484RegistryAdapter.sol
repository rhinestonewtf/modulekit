// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

import { IERC7484 } from "./interfaces/IERC7484.sol";

abstract contract ERC7484RegistryAdapter {
    // registry address
    IERC7484 public immutable REGISTRY;

    /**
     * Contract constructor
     * @dev sets the registry as an immutable variable
     *
     * @param _registry The registry address
     */
    constructor(IERC7484 _registry) {
        // set the registry
        REGISTRY = _registry;
    }
}
