// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../common/IERC1271.sol";
import { ICondition } from "../modulekit/IExecutor.sol";
import { IERC7484Registry, RegistryAdapterForSingletons } from "../common/IERC7484Registry.sol";

/**
 * @dev Represents a single condition configuration. It captures the boundary data and associated condition logic.
 * conditionData - A generic data field that may contain additional context for the condition.
 * condition - An instance of an `ICondition` implementation that encapsulates the condition logic.
 */
struct ConditionConfig {
    ICondition condition;
    bytes conditionData;
}

/**
 * @title ComposableConditionManager
 * @dev This contract manages and checks sets of conditions for different user accounts and associated executors.
 * Conditions are stored as a hash, and checks are made against the stored hash for an account and executor.
 * This allows for modular and composable conditions to be used in a flexible manner.
 */
contract ComposableConditionManager is RegistryAdapterForSingletons {
    // storing the hash of conditions for a given account and executor.
    // This allows for modular and composable conditions to be used in a flexible manner and saves gas
    mapping(address account => mapping(address executor => bytes32 conditionHash)) private
        _conditions;

    error InvalidConditionsProvided(bytes32 hash);
    error ConditionNotMet(address account, address executor, ICondition condition);

    event ConditionHashSet(address indexed account, address indexed executor, bytes32 hash);

    constructor(IERC7484Registry registry) RegistryAdapterForSingletons(registry) { }

    function setAttester(address attester) external {
        _setAttester(msg.sender, attester);
    }

    /**
     * @dev Checks if all conditions for a given account are met. This involves confirming that the conditions hash matches the stored hash
     * and that each individual condition within the set is satisfied.
     * @param account Address of the user/account for which the conditions are checked.
     * @param conditions Array of `ConditionConfig` that represent the set of conditions to be verified.
     * @return true if and only if all conditions are satisfied.
     */
    function checkCondition(
        address account,
        ConditionConfig[] calldata conditions
    )
        public
        view
        returns (bool)
    {
        uint256 length = conditions.length;
        if (length == 0) {
            revert InvalidConditionsProvided(bytes32(0));
        }
        bytes32 validHash = _conditions[account][msg.sender];
        if (validHash == bytes32(0)) {
            revert InvalidConditionsProvided(bytes32(0));
        }
        bytes32 hash = _conditionDigest(conditions);
        if (validHash != hash) revert InvalidConditionsProvided(hash);

        for (uint256 i; i < length; i++) {
            ConditionConfig calldata condition = conditions[i];
            if (
                !condition.condition.checkCondition({
                    account: account,
                    executor: msg.sender,
                    boundries: condition.conditionData,
                    subParams: ""
                })
            ) revert ConditionNotMet(account, msg.sender, condition.condition);
        }

        return true;
    }

    /**
     * @dev Checks if all conditions for a given account are met. This involves confirming that the conditions hash matches the stored hash
     * and that each individual condition within the set is satisfied.
     * @param account Address of the user/account for which the conditions are checked.
     * @param conditions Array of `ConditionConfig` that represent the set of conditions to be verified.
     * @return true if and only if all conditions are satisfied.
     */
    function checkCondition(
        address account,
        ConditionConfig[] calldata conditions,
        bytes[] calldata subParams
    )
        public
        view
        returns (bool)
    {
        uint256 length = conditions.length;
        if (length == 0) {
            revert InvalidConditionsProvided(bytes32(0));
        }
        if (subParams.length != length) revert InvalidConditionsProvided(bytes32(0));
        bytes32 validHash = _conditions[account][msg.sender];
        if (validHash == bytes32(0)) {
            revert InvalidConditionsProvided(bytes32(0));
        }
        bytes32 hash = _conditionDigest(conditions);
        // verify that conditions provided by executor are in fact the user's conditions
        if (validHash != hash) revert InvalidConditionsProvided(hash);

        for (uint256 i; i < length; i++) {
            ConditionConfig calldata condition = conditions[i];
            if (
                !condition.condition.checkCondition({
                    account: account,
                    executor: msg.sender,
                    boundries: condition.conditionData,
                    subParams: subParams[i]
                })
            ) revert ConditionNotMet(account, msg.sender, condition.condition);
        }

        return true;
    }

    /**
     * @dev Computes a unique hash for a given set of conditions.
     * @param conditions Array of `ConditionConfig` whose hash needs to be computed.
     * @return bytes32 A keccak256 hash of the encoded conditions.
     */
    function _conditionDigest(ConditionConfig[] calldata conditions)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(conditions));
    }

    /**
     * @dev Allows a user to set or update the hash of conditions associated with a specific executor.
     * This is useful for modular setups where conditions can be dynamically added or updated.
     * @param executor A moduleKit executor that will be checking these conditions.
     * @param conditions Array of `ConditionConfig` which represent the conditions being set.
     */
    function setHash(address executor, ConditionConfig[] calldata conditions) external {
        address trustedAttester = getAttester(msg.sender);
        // if the user has an attester, make sure that the conditions are in the registry
        if (trustedAttester != address(0)) {
            uint256 length = conditions.length;
            for (uint256 i; i < length; i++) {
                ConditionConfig calldata condition = conditions[i];
                _enforceRegistryCheck(address(condition.condition));
            }
        }

        _conditions[msg.sender][executor] = _conditionDigest(conditions);
        emit ConditionHashSet(msg.sender, executor, _conditions[msg.sender][executor]);
    }

    /**
     * @dev Retrieves the hash of conditions set for a specific account and executor.
     * @param account The user's address.
     * @param executor The entity (usually a smart contract) associated with the conditions.
     * @return bytes32 The stored hash for the given account and executor.
     */
    function getHash(address account, address executor) external view returns (bytes32) {
        return _conditions[account][executor];
    }
}
