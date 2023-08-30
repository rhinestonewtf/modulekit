// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SentinelListLib} from "sentinellist/src/SentinelList.sol";
import "../../modules/executors/IExecutorBase.sol";
import "./RegistryAdapter.sol";

abstract contract ExecutorManager is RegistryAdapter {
    using SentinelListLib for SentinelListLib.SentinelList;

    event TrustedAttesterSet(address indexed attester);

    address internal constant SENTINEL_MODULES = address(0x1);

    mapping(address account => mapping(address executor => ExecutorAccessInfo)) public enabledExecutors;

    struct ExecutorAccessInfo {
        bool rootAddressGranted;
        address nextExecutorPointer;
    }

    modifier onlyExecutor(address account) {
        bool executorEnabled = isExecutorEnabled({account: account, executor: msg.sender});
        if (!executorEnabled) revert ExecutorNotEnabled(msg.sender);

        _enforceRegistryCheck(msg.sender);
        _;
    }

    modifier checkRegistry(address executor) {
        _enforceRegistryCheck(executor);
        _;
    }

    modifier onlyEnabledExecutor(address safe) {
        if (enabledExecutors[safe][msg.sender].nextExecutorPointer == address(0)) {
            revert ExecutorNotEnabled(msg.sender);
        }
        _;
    }

    modifier noZeroOrSentinelExecutor(address executor) {
        if (executor == address(0) || executor == SENTINEL_MODULES) {
            revert InvalidExecutorAddress(executor);
        }
        _;
    }

    function setTrustedAttester(address attester) external {
        _setAttester(msg.sender, attester);
    }
    /**
     * @notice Called by a Safe to enable a executor on a Safe. To be called by a safe.
     * @param executor ISafeProtocolExecutor A executor that has to be enabled
     * @param allowRootAccess Bool indicating whether root access to be allowed.
     */

    function enableExecutor(address executor, bool allowRootAccess)
        external
        noZeroOrSentinelExecutor(executor)
        checkRegistry(executor)
    {
        ExecutorAccessInfo storage senderSentinelExecutor = enabledExecutors[msg.sender][SENTINEL_MODULES];
        ExecutorAccessInfo storage senderExecutor = enabledExecutors[msg.sender][executor];

        if (senderExecutor.nextExecutorPointer != address(0)) {
            revert ExecutorAlreadyEnabled(msg.sender, executor);
        }

        if (senderSentinelExecutor.nextExecutorPointer == address(0)) {
            senderSentinelExecutor.rootAddressGranted = false;
            senderSentinelExecutor.nextExecutorPointer = SENTINEL_MODULES;
        }

        senderExecutor.nextExecutorPointer = senderSentinelExecutor.nextExecutorPointer;
        senderExecutor.rootAddressGranted = false;
        senderSentinelExecutor.nextExecutorPointer = executor;

        emit ExecutorEnabled(msg.sender, executor);
    }
    /**
     * @notice Disable a executor. This function should be called by Safe.
     * @param executor Executor to be disabled
     */

    function disableExecutor(address prevExecutor, address executor) external noZeroOrSentinelExecutor(executor) {
        ExecutorAccessInfo storage prevExecutorInfo = enabledExecutors[msg.sender][prevExecutor];
        ExecutorAccessInfo storage executorInfo = enabledExecutors[msg.sender][executor];

        if (prevExecutorInfo.nextExecutorPointer != executor) {
            revert InvalidPrevExecutorAddress(prevExecutor);
        }

        prevExecutorInfo.nextExecutorPointer = executorInfo.nextExecutorPointer;
        prevExecutorInfo.rootAddressGranted = executorInfo.rootAddressGranted;

        executorInfo.nextExecutorPointer = address(0);
        executorInfo.rootAddressGranted = false;
        emit ExecutorDisabled(msg.sender, executor);
    }
    /**
     * @notice Returns if an executor is enabled
     * @return True if the executor is enabled
     */

    function isExecutorEnabled(address account, address executor) public view returns (bool) {
        return SENTINEL_MODULES != executor && enabledExecutors[account][executor].nextExecutorPointer != address(0);
    }

    function executeTransaction(address account, ExecutorTransaction calldata transaction)
        external
        onlyExecutor(account)
        returns (bytes[] memory data)
    {
        // Initialize a new array of bytes with the same length as the transaction actions
        uint256 length = transaction.actions.length;
        data = new bytes[](length);

        // Loop through all the actions in the transaction
        for (uint256 i; i < length; ++i) {
            address to = transaction.actions[i].to;
            ExecutorAction calldata safeProtocolAction = transaction.actions[i];

            // revert if executor is calling a transaction on avatar or manager
            if (to == address(this) || to == account) {
                revert InvalidToFieldInSafeProtocolAction(account, bytes32(0), 0);
            }

            // Execute the action and store the success status and returned data
            (bool isActionSuccessful, bytes memory resultData) = _execTransationOnSmartAccount(
                account, safeProtocolAction.to, safeProtocolAction.value, safeProtocolAction.data
            );

            // If the action was not successful, revert the transaction
            if (!isActionSuccessful) {
                revert ActionExecutionFailed(account, transaction.metadataHash, i);
            } else {
                data[i] = resultData;
            }
        }
    }

    /**
     * @notice Returns an array of executors enabled for a Safe address.
     *         If all entries fit into a single page, the next pointer will be 0x1.
     *         If another page is present, next will be the last element of the returned array.
     * @param start Start of the page. Has to be a executor or start pointer (0x1 address)
     * @param pageSize Maximum number of executors that should be returned. Has to be > 0
     * @return array Array of executors.
     * @return next Start of the next page.
     */
    function getExecutorsPaginated(address start, uint256 pageSize, address safe)
        external
        view
        returns (address[] memory array, address next)
    {
        if (pageSize == 0) {
            revert ZeroPageSizeNotAllowed();
        }

        if (!(start == SENTINEL_MODULES || isExecutorEnabled(safe, start))) {
            revert InvalidExecutorAddress(start);
        }
        // Init array with max page size
        array = new address[](pageSize);

        // Populate return array
        uint256 executorCount = 0;
        next = enabledExecutors[safe][start].nextExecutorPointer;
        while (next != address(0) && next != SENTINEL_MODULES && executorCount < pageSize) {
            array[executorCount] = next;
            next = enabledExecutors[safe][next].nextExecutorPointer;
            executorCount++;
        }

        // This check is required because the enabled executor list might not be initialised yet. e.g. no enabled executors for a safe ever before
        if (executorCount == 0) {
            next = SENTINEL_MODULES;
        }

        /**
         * Because of the argument validation, we can assume that the loop will always iterate over the valid executor list values
         *       and the `next` variable will either be an enabled executor or a sentinel address (signalling the end).
         *
         *       If we haven't reached the end inside the loop, we need to set the next pointer to the last element of the executors array
         *       because the `next` variable (which is a executor by itself) acting as a pointer to the start of the next page is neither
         *       included to the current page, nor will it be included in the next one if you pass it as a start.
         */
        if (next != SENTINEL_MODULES && executorCount != 0) {
            next = array[executorCount - 1];
        }
        // Set correct size of returned array
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(array, executorCount)
        }
    }

    function _execTransationOnSmartAccount(address account, address to, uint256 value, bytes memory data)
        internal
        virtual
        returns (bool, bytes memory);

    event ExecutorEnabled(address indexed account, address indexed executor);
    event ExecutorDisabled(address indexed account, address indexed executor);

    error ExecutorRequiresRootAccess(address sender);
    error ExecutorNotEnabled(address executor);
    error ExecutorEnabledOnlyForRootAccess(address executor);
    error ExecutorAccessMismatch(address executor, bool requiresRootAccess, bool providedValue);
    error ActionExecutionFailed(address safe, bytes32 metadataHash, uint256 index);
    error RootAccessActionExecutionFailed(address safe, bytes32 metadataHash);
    error ExecutorAlreadyEnabled(address safe, address executor);
    error InvalidExecutorAddress(address executor);
    error InvalidToFieldInSafeProtocolAction(address account, bytes32 metadataHash, uint256 index);
    error InvalidPrevExecutorAddress(address executor);
    error ZeroPageSizeNotAllowed();
}
