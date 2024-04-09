// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ExecutorBase } from "./ERC7579ExecutorBase.sol";

abstract contract SchedulingBase is ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidExecution();
    error InvalidInstall();
    error InvalidJob();

    event ExecutionAdded(address indexed smartAccount, uint256 indexed jobId);
    event ExecutionTriggered(address indexed smartAccount, uint256 indexed jobId);
    event ExecutionStatusUpdated(address indexed smartAccount, uint256 indexed jobId);
    event ExecutionsCancelled(address indexed smartAccount);

    mapping(address smartAccount => mapping(uint256 jobId => ExecutionConfig)) internal
        _executionLog;

    mapping(address smartAccount => uint256 jobCount) internal _accountJobCount;

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
        if (_accountJobCount[msg.sender] != 0) {
            revert InvalidInstall();
        }

        (
            uint48 executeInterval,
            uint16 numberOfExecutions,
            uint48 startDate,
            bytes memory executionData
        ) = abi.decode(data, (uint48, uint16, uint48, bytes));

        uint256 jobId = _accountJobCount[msg.sender] + 1;
        _accountJobCount[msg.sender]++;

        _executionLog[msg.sender][jobId] = ExecutionConfig({
            numberOfExecutionsCompleted: 0,
            isEnabled: true,
            lastExecutionTime: 0,
            executeInterval: executeInterval,
            numberOfExecutions: numberOfExecutions,
            startDate: startDate,
            executionData: executionData
        });

        emit ExecutionAdded(msg.sender, jobId);
    }

    function onUninstall(bytes calldata) external {
        uint256 count = _accountJobCount[msg.sender];
        for (uint256 i = 1; i <= count; i++) {
            delete _executionLog[msg.sender][i];
        }
        _accountJobCount[msg.sender] = 0;

        emit ExecutionsCancelled(msg.sender);
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return _accountJobCount[smartAccount] != 0;
    }

    function addOrder(ExecutionConfig calldata executionConfig) external {
        _createExecution(executionConfig);
    }

    function toggleOrder(uint256 jobId) external {
        ExecutionConfig storage executionConfig = _executionLog[msg.sender][jobId];
        executionConfig.isEnabled = !executionConfig.isEnabled;
        emit ExecutionStatusUpdated(msg.sender, jobId);
    }

    function getAccountJobDetails(
        address smartAccount,
        uint256 jobId
    )
        external
        view
        returns (ExecutionConfig memory)
    {
        return _executionLog[smartAccount][jobId];
    }

    function getAccountJobCount(address smartAccount) external view returns (uint256) {
        return _accountJobCount[smartAccount];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    // abstract methohd to be implemented by the inheriting contract
    function executeOrder(uint256 jobId) external virtual;

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _createExecution(ExecutionConfig calldata data) internal {
        uint256 jobId = _accountJobCount[msg.sender] + 1;
        _accountJobCount[msg.sender]++;

        _executionLog[msg.sender][jobId] = ExecutionConfig({
            numberOfExecutionsCompleted: 0,
            isEnabled: true,
            lastExecutionTime: 0,
            executeInterval: data.executeInterval,
            numberOfExecutions: data.numberOfExecutions,
            startDate: data.startDate,
            executionData: data.executionData
        });

        emit ExecutionAdded(msg.sender, jobId);
    }

    function _isExecutionValid(uint256 jobId) internal view {
        ExecutionConfig storage executionConfig = _executionLog[msg.sender][jobId];

        if (!executionConfig.isEnabled) {
            revert InvalidExecution();
        }

        if (executionConfig.lastExecutionTime + executionConfig.executeInterval < block.timestamp) {
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
