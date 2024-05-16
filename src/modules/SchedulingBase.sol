// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "./ERC7579ExecutorBase.sol";

abstract contract SchedulingBase is ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidExecution();

    event ExecutionAdded(address indexed smartAccount, uint256 indexed jobId);
    event ExecutionTriggered(address indexed smartAccount, uint256 indexed jobId);
    event ExecutionStatusUpdated(address indexed smartAccount, uint256 indexed jobId);
    event ExecutionsCancelled(address indexed smartAccount);

    mapping(address smartAccount => mapping(uint256 jobId => ExecutionConfig)) public executionLog;

    mapping(address smartAccount => uint256 jobCount) public accountJobCount;

    struct ExecutionConfig {
        uint48 executeInterval;
        uint16 numberOfExecutions;
        uint16 numberOfExecutionsCompleted;
        uint48 startDate;
        bool isEnabled;
        uint48 lastExecutionTime;
        bytes executionData;
    }

    struct ExecutorAccess {
        uint256 jobId;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        address account = msg.sender;
        if (isInitialized(account)) {
            revert AlreadyInitialized(account);
        }

        _createExecution({ orderData: data });
    }

    function onUninstall(bytes calldata) external {
        address account = msg.sender;

        uint256 count = accountJobCount[account];
        for (uint256 i = 1; i <= count; i++) {
            delete executionLog[account][i];
        }
        accountJobCount[account] = 0;

        emit ExecutionsCancelled(account);
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        return accountJobCount[smartAccount] != 0;
    }

    function addOrder(bytes calldata orderData) external {
        address account = msg.sender;
        if (!isInitialized(account)) revert NotInitialized(account);

        _createExecution({ orderData: orderData });
    }

    function toggleOrder(uint256 jobId) external {
        address account = msg.sender;

        ExecutionConfig storage executionConfig = executionLog[account][jobId];

        if (executionConfig.numberOfExecutions == 0) {
            revert InvalidExecution();
        }

        executionConfig.isEnabled = !executionConfig.isEnabled;

        emit ExecutionStatusUpdated(account, jobId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    // abstract methohd to be implemented by the inheriting contract
    function executeOrder(uint256 jobId) external virtual;

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _createExecution(bytes calldata orderData) internal {
        address account = msg.sender;

        uint256 jobId = accountJobCount[account] + 1;
        accountJobCount[account]++;

        executionLog[account][jobId] = ExecutionConfig({
            numberOfExecutionsCompleted: 0,
            isEnabled: true,
            lastExecutionTime: 0,
            executeInterval: uint48(bytes6(orderData[0:6])),
            numberOfExecutions: uint16(bytes2(orderData[6:8])),
            startDate: uint48(bytes6(orderData[8:14])),
            executionData: orderData[14:]
        });

        emit ExecutionAdded(account, jobId);
    }

    function _isExecutionValid(uint256 jobId) internal view {
        ExecutionConfig storage executionConfig = executionLog[msg.sender][jobId];

        if (!executionConfig.isEnabled) {
            revert InvalidExecution();
        }

        if (executionConfig.lastExecutionTime + executionConfig.executeInterval > block.timestamp) {
            revert InvalidExecution();
        }

        if (executionConfig.numberOfExecutionsCompleted >= executionConfig.numberOfExecutions) {
            revert InvalidExecution();
        }

        if (executionConfig.startDate > block.timestamp) {
            revert InvalidExecution();
        }
    }

    modifier canExecute(uint256 jobId) {
        _isExecutionValid(jobId);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
