// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.18;

import { IERC165 } from "forge-std/interfaces/IERC165.sol";

/**
 *  Structs that are compatible with Safe{Core} Protocol Specs.
 *  https://github.com/safe-global/safe-core-protocol/blob/main/contracts/DataTypes.sol
 */
struct ExecutorAction {
    address payable to;
    uint256 value;
    bytes data;
}

struct ExecutorTransaction {
    ExecutorAction[] actions;
    uint256 nonce;
    bytes32 metadataHash;
}

struct ExecutorRootAccess {
    ExecutorAction action;
    uint256 nonce;
    bytes32 metadataHash;
}

/**
 * @title IExecutorBase - An interface that a Safe executor should implement
 * @notice Interface is an extention of Safe{Core} Protocol Specs.
 */
interface IExecutorBase is IERC165 {
    /**
     * @notice A funtion that returns name of the executor
     * @return name string name of the executor
     */
    function name() external view returns (string memory name);

    /**
     * @notice A funtion that returns version of the executor
     * @return version string version of the executor
     */
    function version() external view returns (string memory version);

    /**
     * @notice A funtion that returns version of the executor.
     *         TODO: Define types of metadata provider and possible values of location in each of the cases.
     * @return providerType uint256 Type of metadata provider
     * @return location bytes
     */
    function metadataProvider()
        external
        view
        returns (uint256 providerType, bytes memory location);

    /**
     * @notice A function that indicates if the executor requires root access to a Safe.
     * @return requiresRootAccess True if root access is required, false otherwise.
     */
    function requiresRootAccess() external view returns (bool requiresRootAccess);
}

interface IModuleManager {
    function executeTransaction(ExecutorTransaction calldata transaction)
        external
        returns (bytes[] memory data);
}

interface IExecutorManager {
    function executeTransaction(
        address account,
        ExecutorTransaction calldata transaction
    )
        external
        returns (bytes[] memory data);
}

library ModuleExecLib {
    function exec(
        IExecutorManager manager,
        address account,
        ExecutorAction memory action
    )
        internal
        returns (bytes[] memory data)
    {
        ExecutorAction[] memory actions = new ExecutorAction[](1);
        actions[0] = action;

        ExecutorTransaction memory transaction =
            ExecutorTransaction({ actions: actions, nonce: 0, metadataHash: "" });

        return manager.executeTransaction(account, transaction);
    }

    function exec(
        IExecutorManager manager,
        address account,
        ExecutorAction[] memory actions
    )
        internal
        returns (bytes[] memory data)
    {
        ExecutorTransaction memory transaction =
            ExecutorTransaction({ actions: actions, nonce: 0, metadataHash: "" });

        return manager.executeTransaction(account, transaction);
    }

    function exec(
        IExecutorManager manager,
        address account,
        address target,
        bytes memory callData
    )
        internal
        returns (bytes[] memory data)
    {
        ExecutorAction memory action =
            ExecutorAction({ to: payable(target), value: 0, data: callData });
        return exec(manager, account, action);
    }
}

interface ICondition {
    function checkCondition(
        address account,
        address executor,
        bytes calldata boundries,
        bytes calldata subParams
    )
        external
        view
        returns (bool);
}
