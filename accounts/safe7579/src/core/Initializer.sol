// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { EventManager } from "./EventManager.sol";
import { ISafe7579Init } from "../interfaces/ISafe7579Init.sol";
import "./ModuleManager.sol";
import { HookManager } from "./HookManager.sol";

abstract contract Initializer is ISafe7579Init, HookManager, EventManager {
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;
    using SentinelListLib for SentinelListLib.SentinelList;

    event Safe7579Initialized(address indexed safe);

    function initializeAccountWithRegistry(
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit calldata hook,
        RegistryInit calldata registryInit
    )
        public
        payable
    {
        _configureRegistry(registryInit.registry, registryInit.attesters, registryInit.threshold);
        _initModules(executors, fallbacks, hook);
    }

    function initializeAccountWithRegistry(
        ModuleInit[] calldata validators,
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit calldata hook,
        RegistryInit calldata registryInit
    )
        public
        payable
    {
        _configureRegistry(registryInit.registry, registryInit.attesters, registryInit.threshold);
        _initModules(validators, executors, fallbacks, hook);
    }

    function initializeAccount(
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit calldata hook
    )
        public
        payable
    {
        _initModules(executors, fallbacks, hook);
    }

    function initializeAccount(
        ModuleInit[] calldata validators,
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit calldata hook
    )
        public
        payable
    {
        _initModules(validators, executors, fallbacks, hook);
    }

    function launchpadValidators(ModuleInit[] calldata validators) external payable override {
        $validators.init({ account: msg.sender });
        uint256 length = validators.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata validator = validators[i];
            $validators.push({ account: msg.sender, newEntry: validator.module });
            // @dev No events emitted here. Launchpad is expected to do this.
            // at this point, the safeproxy singleton is not yet updated to the SafeSingleton
            // calling execTransactionFromModule is not available yet.
        }
    }

    function _initModules(
        ModuleInit[] calldata validators,
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit calldata hook
    )
        internal
    {
        $validators.init({ account: msg.sender });
        uint256 length = validators.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata validator = validators[i];
            _installValidator(validator.module, validator.initData);
        }
        _initModules(executors, fallbacks, hook);
    }

    function _initModules(
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit calldata hook
    )
        internal
    {
        ModuleManagerStorage storage $mms = $moduleManager[msg.sender];
        // this will revert if already initialized
        // TODO: check that validator list is already initialized
        $mms._executors.init();

        uint256 length = executors.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata executor = executors[i];
            _installExecutor(executor.module, executor.initData);
            _emitModuleInstall(MODULE_TYPE_EXECUTOR, executor.module);
        }

        length = fallbacks.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata _fallback = fallbacks[i];
            _installFallbackHandler(_fallback.module, _fallback.initData);
            _emitModuleInstall(MODULE_TYPE_FALLBACK, _fallback.module);
        }

        _installHook(hook.module, hook.initData);
        _emitModuleInstall(MODULE_TYPE_HOOK, hook.module);

        emit Safe7579Initialized(msg.sender);
    }
}
