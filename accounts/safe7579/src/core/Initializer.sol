// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISafe7579Init } from "../interfaces/ISafe7579Init.sol";
import { HookManager } from "./HookManager.sol";
import { ModuleManagerStorage } from "./ModuleManager.sol";
import { IERC7484 } from "../interfaces/IERC7484.sol";
import { SentinelList4337Lib } from "sentinellist/SentinelList4337.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";

/**
 * Functions that can be used to initialze Safe7579 for a Safe Account
 */
abstract contract Initializer is ISafe7579Init, HookManager {
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;
    using SentinelListLib for SentinelListLib.SentinelList;

    event Safe7579Initialized(address indexed safe);

    error InvalidInitData(address safe);

    /**
     * This function is intended to be called by Launchpad.validateUserOp()
     * @dev it will initialize the SentinelList4337 list for validators, and sstore all
     * validators
     * @dev Since this function has to be 4337 compliant (storage access), only validator storage is  acccess
     * @dev Note: this function DOES NOT call onInstall() on the validator modules or emit
     * ModuleInstalled events. this has to be done by the launchpad
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
     * This function can be called by the Launchpad.initSafe7579() or by already existing Safes that
     * want to use Safe7579
     * if this is called by the Launchpad, it is expected that launchpadValidators() was called
     * previously, and the param validators is empty
     * @param validators validator modules and initData
     * @param executors executor modules and initData
     * @param executors executor modules and initData
     * @param fallbacks fallback modules and initData
     * @param hook hook module and initData
     * @param registryInit (OPTIONAL) registry, attesters and threshold for IERC7484 Registry
     *                    If not provided, the registry will be set to the zero address, and no
     *                    registry checks will be performed
     */
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
                // enable module on Safe7579,  initialize module via Safe, emit events
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
            // enable module on Safe7579,  initialize module via Safe, emit events
            _installExecutor(executor.module, executor.initData);
        }

        length = fallbacks.length;
        for (uint256 i; i < length; i++) {
            ModuleInit calldata _fallback = fallbacks[i];
            // enable module on Safe7579,  initialize module via Safe, emit events
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
        onlyEntryPointOrSelf
    {
        _configureRegistry(registry, attesters, threshold);
    }
}
