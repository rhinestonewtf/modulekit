// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC7579HookDestruct } from "@rhinestone/modulekit/src/modules/ERC7579HookDestruct.sol";
import { IHookPolicy } from "./IHookPolicy.sol";
import { SENTINEL, SentinelListLib } from "sentinellist/SentinelList.sol";
import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";
import { SENTINEL as SENTINELBytes32, LinkedBytes32Lib } from "sentinellist/SentinelListBytes32.sol";
import "forge-std/console2.sol";

type PolicyConfig is bytes32;

type hookFlag is bool;

contract PermissionHook is ERC7579HookDestruct {
    using LinkedBytes32Lib for LinkedBytes32Lib.LinkedBytes32;
    using HookEncodingLib for bytes32;
    using HookEncodingLib for ConfigParam;

    struct ConfigParam {
        hookFlag isExecutorHook;
        hookFlag isValidatorHook;
        hookFlag isConfigHook;
        address hook;
    }

    error SubHookFailed(bytes32);

    uint256 constant MAX_HOOK_NR = 16;

    mapping(address smartAccount => LinkedBytes32Lib.LinkedBytes32 globalSubHooks) internal
        $globalSubHooks;
    mapping(address smartAccount => mapping(address module => LinkedBytes32Lib.LinkedBytes32))
        internal $moduleSubHooks;

    function execSubHooks(
        address module,
        bytes memory callData,
        function (bytes32) returns(bool) checkFlagFn
    )
        internal
    {
        (bytes32[] memory globalHooks,) =
            $globalSubHooks[msg.sender].getEntriesPaginated(SENTINELBytes32, MAX_HOOK_NR);

        uint256 length = globalHooks.length;

        for (uint256 i; i < length; i++) {
            bytes32 _globalHook = globalHooks[i];
            // console2.logBytes32(_globalHook);
            // console2.log("flag", checkFlagFn(_globalHook));
            // if (!checkFlagFn(_globalHook)) continue;
            (bool success,) = _globalHook.decodeAddress().call(callData);
            if (!success) revert SubHookFailed(_globalHook);
        }

        LinkedBytes32Lib.LinkedBytes32 storage $moduleHooks = $moduleSubHooks[msg.sender][module];
        // TODO: make this nicer
        if (!$moduleHooks.alreadyInitialized()) return;

        (bytes32[] memory moduleHooks,) =
            $moduleSubHooks[msg.sender][module].getEntriesPaginated(SENTINELBytes32, MAX_HOOK_NR);
        length = moduleHooks.length;
        for (uint256 i; i < length; i++) {
            bytes32 _moduleHook = moduleHooks[i];

            if (!checkFlagFn(_moduleHook)) continue;
            (bool success,) = _moduleHook.decodeAddress().call(callData);
            if (!success) revert SubHookFailed(_moduleHook);
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
            $globalSubHooks[msg.sender].push(_packed);
        }
    }

    function installModuleHooks(address module, ConfigParam[] calldata params) public {
        uint256 length = params.length;
        $moduleSubHooks[msg.sender][module].init();
        for (uint256 i; i < length; i++) {
            ConfigParam calldata conf = params[i];
            bytes32 _packed = conf.pack();
            // check if the hook is already enabled for global
            if ($globalSubHooks[msg.sender].contains(_packed)) continue;
            $moduleSubHooks[msg.sender][module].push(_packed);
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
        execSubHooks({
            module: module,
            callData: abi.encodeCall(
                IHookPolicy.onExecute, (msg.sender, module, target, value, callData)
                ),
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
        execSubHooks({
            module: module,
            callData: abi.encodeCall(IHookPolicy.onExecuteBatch, (msg.sender, module, executions)),
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
        execSubHooks({
            module: module,
            callData: abi.encodeCall(
                IHookPolicy.onExecuteFromExecutor, (msg.sender, module, target, value, callData)
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
        execSubHooks({
            module: module,
            callData: abi.encodeCall(
                IHookPolicy.onExecuteBatchFromExecutor, (msg.sender, module, executions)
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
        execSubHooks({
            module: module,
            callData: abi.encodeCall(
                IHookPolicy.onInstallModule, (msg.sender, module, moduleType, installModule, initData)
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
        execSubHooks({
            module: module,
            callData: abi.encodeCall(
                IHookPolicy.onInstallModule,
                (msg.sender, module, moduleType, uninstallModule, deInitData)
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
        return "MultiPlexerHook";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_HOOK;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        // todo
    }
}

library HookEncodingLib {
    function pack(PermissionHook.ConfigParam calldata params)
        internal
        pure
        returns (bytes32 encoded)
    {
        return
            encode(params.hook, params.isExecutorHook, params.isValidatorHook, params.isConfigHook);
    }

    function encode(
        address hook,
        hookFlag isExecutorHook,
        hookFlag isValidatorHook,
        hookFlag isConfigHook
    )
        internal
        pure
        returns (bytes32 encoded)
    {
        assembly {
            encoded := hook
            encoded := or(encoded, shl(8, isExecutorHook))
            encoded := or(encoded, shl(16, isValidatorHook))
            encoded := or(encoded, shl(24, isConfigHook))
        }
        encoded = bytes32(
            (abi.encodePacked(isExecutorHook, isValidatorHook, isConfigHook, bytes5(0), hook))
        );
    }

    function decode(bytes32 encoded)
        internal
        pure
        returns (
            address hook,
            hookFlag isExecutorHook,
            hookFlag isValidatorHook,
            hookFlag isConfigHook
        )
    {
        assembly {
            hook := encoded
            isExecutorHook := shr(8, encoded)
            isValidatorHook := shr(16, encoded)
            isConfigHook := shr(24, encoded)
        }
    }

    function isExecutorHook(bytes32 encoded) internal pure returns (bool) {
        return (uint256(encoded)) & 0xff == 1;
    }

    function is4337Hook(bytes32 encoded) internal pure returns (bool) {
        return (uint256(encoded) >> 8) & 0xff == 1;
    }

    function isConfigHook(bytes32 encoded) internal pure returns (bool) {
        return (uint256(encoded) >> 16) & 0xff == 1;
    }

    function decodeAddress(bytes32 encoded) internal pure returns (address) {
        return address(uint160(uint256(encoded)));
    }
}
