// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICondition } from "../IExecutor.sol";

contract ScheduleCondition is ICondition, ChainlinkTokenPrice {
    struct Params {
        uint256 triggerEveryHours;
    }

    struct Schedule {
        uint256 lastExecuted;
    }

    mapping(address executor => mapping(address account => Schedule)) _schedules;

    event ScheduleUpdated(address account, uint256 lastExecuted);

    function checkCondition(
        address account,
        address executor,
        bytes calldata conditionData,
        bytes calldata
    )
        external
        view
        override
        returns (bool)
    {
        Params memory params = abi.decode(conditionData, (Params));
        Schedule storage scheduleForAccount = _schedules[executor][account];

        return scheduleIsDue(scheduleForAccount, params);
    }

    function scheduleIsDue(
        Schedule storage scheduleForAccount,
        Params memory params
    )
        private
        view
        returns (bool isDue)
    {
        uint256 lastExecuted = scheduleForAccount.lastExecuted;
        if (lastExecuted == 0) return true;
        if (lastExecuted > (block.timestamp + params.triggerEveryHours)) {
            isDue = true;
            return isDue;
        }
    }

    function updateSchedule(address account) external {
        Schedule storage scheduleForAccount = _schedules[msg.sender][account];
        scheduleForAccount.lastExecuted = uint48(block.timestamp);

        emit ScheduleUpdated(account, block.timestamp);
    }
}
