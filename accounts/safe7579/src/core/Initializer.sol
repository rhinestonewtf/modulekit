// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ISafe7579 } from "../ISafe7579.sol";
import "../DataTypes.sol";
import { ModuleManager } from "./ModuleManager.sol";
import { IERC7484 } from "../interfaces/IERC7484.sol";
import { SentinelList4337Lib } from "sentinellist/SentinelList4337.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";

/**
 * Functions that can be used to initialze Safe7579 for a Safe Account
 * @author zeroknots.eth | rhinestone.wtf
 */
abstract contract Initializer is ISafe7579, ModuleManager {
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;
    using SentinelListLib for SentinelListLib.SentinelList;

    event Safe7579Initialized(address indexed safe);

    error InvalidInitData(address safe);

    /**
     * @inheritdoc ISafe7579
     */
    function launchpadValidators(ModuleInit[] calldata validators) external payable override {
        // this will revert if already initialized
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

    /**
     * @inheritdoc ISafe7579
     */
    function initializeAccount(
        ModuleInit[] calldata validators,
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit[] calldata hooks,
        RegistryInit calldata registryInit
    )
        public
        payable
    {
        _configureRegistry(registryInit.registry, registryInit.attesters, registryInit.threshold);
        // this will revert if already initialized
        _initModules(validators, executors, fallbacks, hooks);
    }

    /**
     * _initModules may be used via launchpad deploymet or directly by already deployed Safe
     * accounts
     */
    function _initModules(
        ModuleInit[] calldata validators,
        ModuleInit[] calldata executors,
        ModuleInit[] calldata fallbacks,
        ModuleInit[] calldata hooks
    )
        internal
    {
        uint256 length = validators.length;
        // if this function is called by the launchpad, validators will be initialized via
        // launchpadValidators()
        // to avoid double initialization, we check if the validators are already initialized
        if (!$validators.alreadyInitialized({ account: msg.sender })) {
            $validators.init({ account: msg.sender });
            for (uint256 i; i < length; i++) {
                ModuleInit calldata validator = validators[i];
                // enable module on Safe7579,  initialize module via Safe, emit events
                _installValidator(validator.module, validator.initData);
            }
        } else if (length != 0) {
            revert InvalidInitData(msg.sender);
        }

        SentinelListLib.SentinelList storage $executors = $executorStorage[msg.sender];
        // this will revert if already initialized.
        $executors.init();

        length = executors.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata executor = executors[i];
            // enable module on Safe7579,  initialize module via Safe, emit events
            _installExecutor(executor.module, executor.initData);
        }

        length = fallbacks.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata _fallback = fallbacks[i];
            // enable module on Safe7579,  initialize module via Safe, emit events
            _installFallbackHandler(_fallback.module, _fallback.initData);
        }

        length = hooks.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata hook = hooks[i];
            // enable module on Safe7579,  initialize module via Safe, emit events
            _installHook(hook.module, hook.initData);
        }

        emit Safe7579Initialized(msg.sender);
    }

    /**
     * @inheritdoc ISafe7579
     */
    function setRegistry(
        IERC7484 registry,
        address[] calldata attesters,
        uint8 threshold
    )
        external
        onlyEntryPointOrSelf
    {
        _configureRegistry(registry, attesters, threshold);
    }
}
