// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";
import { SENTINEL, SentinelListLib } from "sentinellist/SentinelList.sol";
import "forge-std/console2.sol";

abstract contract SubHook {
    address public immutable HOOK_MULTIPLEXER;

    constructor(address hookMultiplexer) {
        HOOK_MULTIPLEXER = hookMultiplexer;
    }

    modifier onlyMultiPlexer() {
        if (msg.sender != HOOK_MULTIPLEXER) {
            revert("Unauthorized");
        }
        _;
    }

    function onExecute(
        address smartAccount,
        address module,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        virtual
        returns (bytes memory);

    function onExecuteBatch(
        address smartAccount,
        address module,
        Execution[] calldata executions
    )
        external
        virtual
        returns (bytes memory);
}

abstract contract HookMultiPlexer {
    using SentinelListLib for SentinelListLib.SentinelList;

    uint256 internal constant MAX_HOOK_NR = 16;
    mapping(address smartAccount => SentinelListLib.SentinelList globalSubHooks) internal
        $globalSubHooks;
    mapping(address smartAccount => mapping(address module => SentinelListLib.SentinelList))
        internal $moduleSubHooks;

    function installGlobalHooks(address[] memory hooks) public {
        uint256 length = hooks.length;
        for (uint256 i; i < length; i++) {
            $globalSubHooks[msg.sender].push(hooks[i]);
            // TODO check if the hook is already enabled for module
        }
    }

    function installModuleHooks(address module, address[] memory hooks) public {
        uint256 length = hooks.length;
        for (uint256 i; i < length; i++) {
            // check if the hook is already enabled for global
            if ($globalSubHooks[msg.sender].contains(hooks[i])) continue;
            $moduleSubHooks[msg.sender][module].push(hooks[i]);
        }
    }

    function _onExecSubHooks(
        address sourceModule,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
    {
        (address[] memory hooks,) =
            $globalSubHooks[msg.sender].getEntriesPaginated(SENTINEL, MAX_HOOK_NR);

        for (uint256 i = 0; i < hooks.length; i++) {
            SubHook(hooks[i]).onExecute(msg.sender, sourceModule, target, value, callData);
        }

        (hooks,) =
            $moduleSubHooks[msg.sender][sourceModule].getEntriesPaginated(SENTINEL, MAX_HOOK_NR);
        for (uint256 i = 0; i < hooks.length; i++) {
            SubHook(hooks[i]).onExecute(msg.sender, sourceModule, target, value, callData);
        }
    }
}
