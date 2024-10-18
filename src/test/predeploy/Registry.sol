// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC7484 } from "src/Interfaces.sol";
import { MockRegistry } from "src/Mocks.sol";
import { etch } from "../utils/Vm.sol";

address constant REGISTRY_ADDR = 0x000000000069E2a187AEFFb852bF3cCdC95151B2;

function etchRegistry() returns (IERC7484) {
    address _registry = address(new MockRegistry());
    etch(REGISTRY_ADDR, _registry.code);

    return IERC7484(REGISTRY_ADDR);
}
