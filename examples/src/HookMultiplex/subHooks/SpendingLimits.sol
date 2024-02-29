// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { LinkedBytes32Lib } from "sentinellist/SentinelListBytes32.sol";
import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";
import { SubHookBase } from "./SubHookBase.sol";
import { TokenTransactionLib } from "../lib/TokenTransactionLib.sol";
import "forge-std/console2.sol";

// bytes32 constant STORAGE_SLOT = keccak256("permissions.storage");
bytes32 constant STORAGE_SLOT = bytes32(uint256(123_123_123_123));

contract SpendingLimits is SubHookBase {
    using TokenTransactionLib for bytes4;

    struct Limits {
        uint256 totalSpent;
        uint256 limit;
    }

    struct SubHookStorage {
        mapping(address smartAccount => mapping(address token => Limits limit)) limit;
    }

    constructor(address HookMultiplexer) SubHookBase(HookMultiplexer) { }

    function $subHook() internal pure virtual returns (SubHookStorage storage shs) {
        bytes32 position = STORAGE_SLOT;
        assembly {
            shs.slot := position
        }
    }

    function configure(address token, uint256 spendLimit) external {
        Limits storage $limit = $subHook().limit[msg.sender][token];
        $limit.limit = spendLimit;
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
        onlyMultiplexer
        returns (bytes memory hookData)
    {
        if (callData.length < 4) return "";
        if (!bytes4(callData[0:4]).isERC20Transfer()) return "";

        (address to, uint256 amount) = abi.decode(callData[4:], (address, uint256));

        Limits storage $limit = $subHook().limit[smartAccount][target];
        uint256 totalSpent = $limit.totalSpent + amount;
        console2.log("totalSpent", totalSpent);
        require(totalSpent <= $limit.limit, "SpendingLimit: limit exceeded");
        $limit.totalSpent = totalSpent;
    }

    function onExecuteBatch(
        address smartAccount,
        address module,
        Execution[] calldata
    )
        external
        override
        onlyMultiplexer
        returns (bytes memory hookData)
    { }

    function onExecuteFromExecutor(
        address smartAccount,
        address module,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        override
        onlyMultiplexer
        returns (bytes memory hookData)
    { }

    function onExecuteBatchFromExecutor(
        address smartAccount,
        address module,
        Execution[] calldata executions
    )
        external
        override
        onlyMultiplexer
        returns (bytes memory hookData)
    { }

    function onInstallModule(
        address smartAccount,
        address module,
        uint256 moduleType,
        address moduleToInstall,
        bytes calldata initData
    )
        external
        onlyMultiplexer
        returns (bytes memory hookData)
    { }

    function onUninstallModule(
        address smartAccount,
        address module,
        uint256 moduleType,
        address moduleToUninstall,
        bytes calldata deInitData
    )
        external
        onlyMultiplexer
        returns (bytes memory hookData)
    { }

    function onPostCheck(bytes calldata hookData) external returns (bool success) { }
}
