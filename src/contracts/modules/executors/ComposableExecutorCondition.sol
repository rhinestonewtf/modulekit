// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICondition } from "./ICondition.sol";
import { IERC1271 } from "../../../interfaces/IERC1271.sol";

struct ConditionConfig {
    bytes boundriesData;
    ICondition condition;
}

contract ComposableConditionManager {
    mapping(address account => mapping(address executor => bytes32 conditionHash)) private
        _conditions;

    error InvalidConditionsProvided(bytes32 hash);
    error InvalidSignature();
    error ConditionNotMet(address account, address executor, ICondition condition);

    event ConditionHashSet(address indexed account, address indexed executor, bytes32 hash);

    function check(
        address account,
        ConditionConfig[] calldata conditions
    )
        public
        view
        returns (bool)
    {
        bytes32 validHash = _conditions[account][msg.sender];
        if (validHash == bytes32(0)) {
            revert InvalidConditionsProvided(bytes32(0));
        }
        if (conditions.length == 0) {
            revert InvalidConditionsProvided(bytes32(0));
        }
        bytes32 hash = _conditionDigest(conditions);
        if (validHash != hash) revert InvalidConditionsProvided(hash);

        uint256 length = conditions.length;
        for (uint256 i; i < length; i++) {
            ConditionConfig calldata condition = conditions[i];
            if (
                !condition.condition.check({
                    account: account,
                    executor: msg.sender,
                    boundries: condition.boundriesData
                })
            ) revert ConditionNotMet(account, msg.sender, condition.condition);
        }

        return true;
    }

    function _conditionDigest(ConditionConfig[] calldata conditions)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(conditions));
    }

    function setHash(address executor, ConditionConfig[] calldata conditions) external {
        _conditions[msg.sender][executor] = _conditionDigest(conditions);
        emit ConditionHashSet(msg.sender, executor, _conditions[msg.sender][executor]);
    }

    function setHash(
        address account,
        address executor,
        ConditionConfig[] calldata conditions,
        bytes calldata signature
    )
        external
    {
        bytes32 hash = _conditionDigest(conditions);
        if (
            IERC1271(account).isValidSignature(hash, signature)
                != IERC1271.isValidSignature.selector
        ) revert InvalidSignature();
        _conditions[account][executor] = hash;
        emit ConditionHashSet(account, executor, hash);
    }
}
