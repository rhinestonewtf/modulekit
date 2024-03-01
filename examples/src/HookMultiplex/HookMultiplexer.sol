// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";
import { SENTINEL, SentinelListLib } from "sentinellist/SentinelList.sol";
import { SENTINEL as SENTINELBytes32, LinkedBytes32Lib } from "sentinellist/SentinelListBytes32.sol";
import { ERC7579HookDestruct } from "@rhinestone/modulekit/src/modules/ERC7579HookDestruct.sol";
import "forge-std/console2.sol";
import { ISubHook } from "./ISubHook.sol";
import { IHookMultiPlexer, hookFlag } from "./IHookMultiplexer.sol";
import { HookEncodingLib } from "./lib/HookEncodingLib.sol";

bytes32 constant STORAGE_SLOT = bytes32(uint256(1_244_444_444));

contract HookMultiPlexer is ERC7579HookDestruct, IHookMultiPlexer {
    using SentinelListLib for SentinelListLib.SentinelList;
    using LinkedBytes32Lib for LinkedBytes32Lib.LinkedBytes32;
    using HookEncodingLib for ConfigParam;
    using HookEncodingLib for bytes32;

    uint256 internal constant MAX_HOOK_NR = 16;

    error SubHookFailed(bytes32 hook);

    struct MultiPlexerStorage {
        mapping(address smartAccount => LinkedBytes32Lib.LinkedBytes32 globalSubHooks)
            $globalSubHooks;
        mapping(address smartAccount => mapping(address module => LinkedBytes32Lib.LinkedBytes32))
            $moduleSubHooks;
    }

    function $multiplexer() internal returns (MultiPlexerStorage storage strg) {
        bytes32 position = STORAGE_SLOT;
        assembly {
            strg.slot := position
        }
    }

    function installGlobalHooks(ConfigParam[] calldata params) public {
        uint256 length = params.length;
        for (uint256 i; i < length; i++) {
            ConfigParam calldata conf = params[i];
            bytes32 _packed = conf.pack();
            console2.logBytes32(_packed);
            console2.log(
                conf.hook,
                hookFlag.unwrap(conf.isValidatorHook),
                hookFlag.unwrap(conf.isExecutorHook)
            );
            $multiplexer().$globalSubHooks[msg.sender].push(_packed);
        }
    }

    function installModuleHooks(address module, ConfigParam[] calldata params) public {
        uint256 length = params.length;
        $multiplexer().$moduleSubHooks[msg.sender][module].init();
        for (uint256 i; i < length; i++) {
            ConfigParam calldata conf = params[i];
            bytes32 _packed = conf.pack();
            // check if the hook is already enabled for global
            if ($multiplexer().$globalSubHooks[msg.sender].contains(_packed)) continue;
            $multiplexer().$moduleSubHooks[msg.sender][module].push(_packed);
        }
    }

    function configSubHook(address module, bytes32 hook, bytes calldata configCallData) external {
        if (!$multiplexer().$moduleSubHooks[msg.sender][module].contains(hook)) revert();
        (bool success,) = hook.decodeAddress().call(configCallData);
    }

    function onInstall(bytes calldata data) external override {
        $multiplexer().$globalSubHooks[msg.sender].init();
    }

    function onUninstall(bytes calldata data) external override {
        // todo
    }

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual returns (string memory) {
        return "MultiPlexerHook";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_HOOK;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        // todo
    }

    function _execSubHooks(
        address module,
        bytes memory callData,
        function (bytes32) returns(bool) checkFlagFn
    )
        internal
    {
        (bytes32[] memory globalHooks,) = $multiplexer().$globalSubHooks[msg.sender]
            .getEntriesPaginated(SENTINELBytes32, MAX_HOOK_NR);

        uint256 length = globalHooks.length;

        for (uint256 i; i < length; i++) {
            bytes32 _globalHook = globalHooks[i];
            // console2.logBytes32(_globalHook);
            // console2.log("flag", checkFlagFn(_globalHook));
            // if (!checkFlagFn(_globalHook)) continue;
            (bool success,) = _globalHook.decodeAddress().call(callData);
            if (!success) revert SubHookFailed(_globalHook);
        }

        LinkedBytes32Lib.LinkedBytes32 storage $moduleHooks =
            $multiplexer().$moduleSubHooks[msg.sender][module];
        // TODO: make this nicer
        if (!$moduleHooks.alreadyInitialized()) return;

        (bytes32[] memory moduleHooks,) = $multiplexer().$moduleSubHooks[msg.sender][module]
            .getEntriesPaginated(SENTINELBytes32, MAX_HOOK_NR);
        length = moduleHooks.length;
        for (uint256 i; i < length; i++) {
            bytes32 _moduleHook = moduleHooks[i];

            if (!checkFlagFn(_moduleHook)) continue;
            (bool success,) = _moduleHook.decodeAddress().call(callData);
            if (!success) revert SubHookFailed(_moduleHook);
        }
    }

    function onExecute(
        address module,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        _execSubHooks({
            module: module,
            callData: abi.encodeCall(ISubHook.onExecute, (msg.sender, module, target, value, callData)),
            checkFlagFn: HookEncodingLib.is4337Hook
        });
    }

    function onExecuteBatch(
        address module,
        Execution[] calldata executions
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        _execSubHooks({
            module: module,
            callData: abi.encodeCall(ISubHook.onExecuteBatch, (msg.sender, module, executions)),
            checkFlagFn: HookEncodingLib.is4337Hook
        });
    }

    function onExecuteFromExecutor(
        address module,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        _execSubHooks({
            module: module,
            callData: abi.encodeCall(
                ISubHook.onExecuteFromExecutor, (msg.sender, module, target, value, callData)
                ),
            checkFlagFn: HookEncodingLib.isExecutorHook
        });
    }

    function onExecuteBatchFromExecutor(
        address module,
        Execution[] calldata executions
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        _execSubHooks({
            module: module,
            callData: abi.encodeCall(
                ISubHook.onExecuteBatchFromExecutor, (msg.sender, module, executions)
                ),
            checkFlagFn: HookEncodingLib.isExecutorHook
        });
    }

    function onInstallModule(
        address module,
        uint256 moduleType,
        address installModule,
        bytes calldata initData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        _execSubHooks({
            module: module,
            callData: abi.encodeCall(
                ISubHook.onInstallModule, (msg.sender, module, moduleType, installModule, initData)
                ),
            checkFlagFn: HookEncodingLib.isConfigHook
        });
    }

    function onUninstallModule(
        address module,
        uint256 moduleType,
        address uninstallModule,
        bytes calldata deInitData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        _execSubHooks({
            module: module,
            callData: abi.encodeCall(
                ISubHook.onInstallModule, (msg.sender, module, moduleType, uninstallModule, deInitData)
                ),
            checkFlagFn: HookEncodingLib.isConfigHook
        });
    }

    function onPostCheck(bytes calldata hookData)
        internal
        virtual
        override
        returns (bool success)
    { }
}
