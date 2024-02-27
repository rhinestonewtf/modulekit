// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";
import { SENTINEL, SentinelListLib } from "sentinellist/SentinelList.sol";
import { ERC7579HookDestruct } from "@rhinestone/modulekit/src/modules/ERC7579HookDestruct.sol";
import "forge-std/console2.sol";
import { ISubHook } from "./ISubHook.sol";

contract HookMultiPlexer is ERC7579HookDestruct {
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

    function onInstall(bytes calldata data) external override {
        $globalSubHooks[msg.sender].init();
    }

    function onUninstall(bytes calldata data) external override {
        // todo
    }

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual returns (string memory) {
        return "PermissionHook";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_HOOK;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        // todo
    }

    function _delegatecallSubHook(
        bytes4 functionSig,
        address subHook,
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
    { }

    function onExecute(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        console2.log("onExecute: msgSender", msg.sender);
        (address[] memory globalHooks,) =
            $globalSubHooks[msg.sender].getEntriesPaginated(SENTINEL, MAX_HOOK_NR);

        uint256 length = globalHooks.length;
        console2.log("globalHooks.length", length);

        for (uint256 i; i < length; i++) {
            address hook = globalHooks[i];
            (bool success,) = hook.delegatecall(
                abi.encodeCall(ISubHook.onExecute, (msgSender, target, value, callData))
            );
            require(success, "HookMultiPlexer: onExecute: subhook failed");
        }

        // TODO: 
        // implement for loop for module specific hooks
    }

    function onExecuteBatch(
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onExecuteFromExecutor(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onExecuteBatchFromExecutor(
        address msgSender,
        Execution[] calldata
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onInstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onUninstallModule(
        address msgSender,
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onPostCheck(bytes calldata hookData)
        internal
        virtual
        override
        returns (bool success)
    { }
}
