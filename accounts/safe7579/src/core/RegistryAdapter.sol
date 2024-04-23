// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC7484 } from "../interfaces/IERC7484.sol";
import { ExecutionHelper } from "./ExecutionHelper.sol";
import { ISafe } from "../interfaces/ISafe.sol";
import { ISafe7579 } from "../ISafe7579.sol";

/**
 * IERC7484 Registry adapter.
 * this feature is opt-in. The smart account owner can choose to use the registry and which
 * attesters to trust.
 * @author zeroknots.eth | rhinestone.wtf
 */
abstract contract RegistryAdapter is ISafe7579, ExecutionHelper {
    mapping(address smartAccount => IERC7484 registry) internal $registry;

    modifier withRegistry(address module, uint256 moduleType) {
        _checkRegistry(module, moduleType);
        _;
    }

    /**
     * Check on ERC7484 Registry, if suffcient attestations were made
     * This will revert, if not succicient valid attestations are on the registry
     */
    function _checkRegistry(address module, uint256 moduleType) internal view {
        IERC7484 registry = $registry[msg.sender];
        if (address(registry) != address(0)) {
            // this will revert if attestations / threshold are not met
            registry.checkForAccount(msg.sender, module, moduleType);
        }
    }

    /**
     * Configure ERC7484 Registry for Safe
     */
    function _configureRegistry(
        IERC7484 registry,
        address[] calldata attesters,
        uint8 threshold
    )
        internal
    {
        $registry[msg.sender] = registry;
        _exec({
            safe: ISafe(msg.sender),
            target: address(registry),
            value: 0,
            callData: abi.encodeCall(IERC7484.trustAttesters, (threshold, attesters))
        });
        emit ERC7484RegistryConfigured(msg.sender, registry);
    }
}
