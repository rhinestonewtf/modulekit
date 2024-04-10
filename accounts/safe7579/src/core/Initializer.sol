// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISafe7579Init } from "../interfaces/ISafe7579Init.sol";
import "./ModuleManager.sol";
import { HookManager } from "./HookManager.sol";
import { IERC7484 } from "../interfaces/IERC7484.sol";
import "forge-std/console2.sol";

abstract contract Initializer is ISafe7579Init, HookManager {
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;
    using SentinelListLib for SentinelListLib.SentinelList;

    event Safe7579Initialized(address indexed safe);

    error InvalidInitData(address safe);

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

    function initializeAccount(
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
        // this will revert if already initialized
        _initModules(validators, executors, fallbacks, hook);
    }

    function _initModules(
        ModuleInit[] calldata validators,
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit calldata hook
    )
        internal
    {
        uint256 length = validators.length;
        // _initModules may be used via launchpad or directly by already deployed Safe accounts
        // if this function is called by the launchpad, validators will be initialized via
        // launchpadValidators()
        // to avoid double initialization, we check if the validators are already initialized
        if (!$validators.alreadyInitialized({ account: msg.sender })) {
            $validators.init({ account: msg.sender });
            for (uint256 i; i < length; i++) {
                ModuleInit calldata validator = validators[i];
                _installValidator(validator.module, validator.initData);
            }
        } else if (length != 0) {
            revert InvalidInitData(msg.sender);
        }

        ModuleManagerStorage storage $mms = $moduleManager[msg.sender];
        // this will revert if already initialized.
        $mms._executors.init();

        length = executors.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata executor = executors[i];
            _installExecutor(executor.module, executor.initData);
        }

        length = fallbacks.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata _fallback = fallbacks[i];
            _installFallbackHandler(_fallback.module, _fallback.initData);
        }

        _installHook(hook.module, hook.initData);

        emit Safe7579Initialized(msg.sender);
    }

    function setRegistry(
        IERC7484 registry,
        address[] calldata attesters,
        uint8 threshold
    )
        external
    {
        _configureRegistry(registry, attesters, threshold);
    }
}
