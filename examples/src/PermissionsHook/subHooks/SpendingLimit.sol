// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SubHook } from "../HookMultiplexer.sol";
import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";
import { TransactionDetectionLib } from "../TransactionDetectionLib.sol";
import "forge-std/console2.sol";

contract SpendingLimit is SubHook {
    using TransactionDetectionLib for bytes4;

    struct Limits {
        uint256 totalSpent;
        uint256 limit;
    }

    mapping(address smartAccount => mapping(address token => Limits limit)) internal limit;

    constructor(address HookMultiplexer) SubHook(HookMultiplexer) { }

    function setLimit(address token, uint256 spendLimit) external {
        limit[msg.sender][token].limit = spendLimit;
    }

    function onExecute(
        address smartAccount,
        address module,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        override
        onlyMultiPlexer
        returns (bytes memory)
    {
        // only handle ERC20 transfers
        if (callData.length < 4) return "";
        if (!bytes4(callData[0:4]).isERC20Transfer()) return "";

        (address to, uint256 amount) = abi.decode(callData[4:], (address, uint256));

        Limits storage $limit = limit[smartAccount][target];
        uint256 totalSpent = $limit.totalSpent + amount;
        console2.log("totalSpent", totalSpent);
        require(totalSpent <= $limit.limit, "SpendingLimit: limit exceeded");
        $limit.totalSpent = totalSpent;
    }

    function onExecuteBatch(
        address smartAccount,
        address module,
        Execution[] calldata executions
    )
        external
        override
        onlyMultiPlexer
        returns (bytes memory)
    { }
}
