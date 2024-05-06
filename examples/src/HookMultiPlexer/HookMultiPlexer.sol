// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ModuleBase } from "modulekit/src/modules/ERC7579ModuleBase.sol";
import { ERC7484RegistryAdapter } from "modulekit/src/Modules.sol";
import { IERC7579Account, IERC7579Hook } from "modulekit/src/external/ERC7579.sol";
import { SigHookInit, Config, HookType, HookAndContext } from "./DataTypes.sol";
import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import {
    ModeLib,
    CallType,
    ModeCode,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    CALLTYPE_DELEGATECALL
} from "erc7579/lib/ModeLib.sol";
import { ExecutionLib, Execution } from "erc7579/lib/ExecutionLib.sol";
import { HookMultiPlexerLib } from "./HookMultiPlexerLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { IERC7484 } from "modulekit/src/interfaces/IERC7484.sol";

/**
 * @title HookMultiPlexer
 * @dev A module that allows to add multiple hooks to a smart account
 * @author Rhinestone
 */
contract HookMultiPlexer is IERC7579Hook, ERC7579ModuleBase, ERC7484RegistryAdapter {
    using HookMultiPlexerLib for *;
    using LibSort for uint256[];
    using LibSort for address[];

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error UnsupportedHookType();

    // offset used to decode ERC7579 execution callData
    uint256 constant EXEC_OFFSET = 100;

    // account => Config
    mapping(address account => Config config) internal accountConfig;

    /**
     * Contract constructor
     * @dev sets the registry as an immutable variable
     *
     * @param _registry The registry address
     */
    constructor(IERC7484 _registry) ERC7484RegistryAdapter(_registry) { }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initializes the module with the hooks
     * @dev data is encoded as follows: abi.encode(
     *      address[] globalHooks,
     *      address[] valueHooks,
     *      address[] delegatecallHooks,
     *      SigHookInit[] sigHooks,
     *      SigHookInit[] targetSigHooks
     * )
     *
     * @param data encoded data containing the hooks
     */
    function onInstall(bytes calldata data) external override {
        // check if the module is already initialized and revert if it is
        if (isInitialized(msg.sender)) revert AlreadyInitialized(msg.sender);

        // decode the hook arrays
        (
            address[] calldata globalHooks,
            address[] calldata valueHooks,
            address[] calldata delegatecallHooks,
            SigHookInit[] calldata sigHooks,
            SigHookInit[] calldata targetSigHooks
        ) = data.decodeOnInstall();

        // cache the storage config
        Config storage $config = $getConfig(msg.sender);

        // require global hooks to be unique
        globalHooks.requireSortedAndUnique();
        // require value hooks to be unique
        valueHooks.requireSortedAndUnique();
        // require delegatecall hooks to be unique
        delegatecallHooks.requireSortedAndUnique();

        // set the hooks
        $config.globalHooks = globalHooks;
        $config.delegatecallHooks = delegatecallHooks;
        $config.valueHooks = valueHooks;

        // cache the length of the sig hooks
        uint256 length = sigHooks.length;
        // array to store the sigs
        uint256[] memory sigs = new uint256[](length);
        // iterate over the sig hooks
        for (uint256 i; i < length; i++) {
            // cache the sig hook
            SigHookInit calldata _sigHook = sigHooks[i];
            // require the subhooks to be unique
            _sigHook.subHooks.requireSortedAndUnique();
            // add the sig to the sigs array
            sigs[i] = uint256(bytes32(_sigHook.sig));
            // set the sig hooks
            $config.sigHooks[_sigHook.sig] = _sigHook.subHooks;
        }

        // sort the sigs
        sigs.insertionSort();
        // uniquify the sigs
        sigs.uniquifySorted();

        // add the sigs to the sigs array
        length = sigs.length;
        for (uint256 i; i < length; i++) {
            $config.sigs.push(bytes4(bytes32(sigs[i])));
        }

        // cache the length of the target sig hooks
        length = targetSigHooks.length;
        // array to store the target sigs
        uint256[] memory targetSigs = new uint256[](length);
        // iterate over the target sig hooks
        for (uint256 i; i < length; i++) {
            // cache the target sig hook
            SigHookInit calldata _targetSigHook = targetSigHooks[i];
            // require the subhooks to be unique
            _targetSigHook.subHooks.requireSortedAndUnique();
            // add the target sig to the target sigs array
            targetSigs[i] = uint256(bytes32(_targetSigHook.sig));
            // set the target sig hooks
            $config.targetSigHooks[_targetSigHook.sig] = _targetSigHook.subHooks;
        }

        // sort the target sigs
        targetSigs.insertionSort();
        // uniquify the target sigs
        targetSigs.uniquifySorted();

        // add the target sigs to the target sigs array
        length = targetSigs.length;
        for (uint256 i; i < length; i++) {
            $config.targetSigs.push(bytes4(bytes32(targetSigs[i])));
        }
    }

    /**
     * Uninstalls the module
     * @dev deletes all the hooks
     */
    function onUninstall(bytes calldata) external override {
        // cache the storage config
        Config storage $config = $getConfig(msg.sender);

        // delete all the hook arrays
        delete $config.globalHooks;
        delete $config.delegatecallHooks;
        delete $config.valueHooks;

        // cache the length of the sigs
        uint256 length = $config.sigs.length;
        // iterate over the sigs
        for (uint256 i; i < length; i++) {
            // delete the sig hooks
            delete $config.sigHooks[$config.sigs[i]];
        }
        // delete the sigs
        delete $config.sigs;

        // cache the length of the target sigs
        length = $config.targetSigs.length;
        // iterate over the target sigs
        for (uint256 i; i < length; i++) {
            // delete the target sig hooks
            delete $config.targetSigHooks[$config.targetSigs[i]];
        }
        // delete the target sigs
        delete $config.targetSigs;
    }

    /**
     * Checks if the module is initialized
     * @dev short curcuiting the check for efficiency
     *
     * @param smartAccount address of the smart account
     *
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) public view returns (bool) {
        // cache the storage config
        Config storage $config = $getConfig(smartAccount);
        // if any hooks are set, the module is initialized
        return $config.globalHooks.length != 0 || $config.delegatecallHooks.length != 0
            || $config.valueHooks.length != 0 || $config.sigs.length != 0
            || $config.targetSigs.length != 0;
    }

    /**
     * Returns the hooks for the account
     * @dev this function is not optimized and should only be used when calling from offchain
     *
     * @param account address of the account
     *
     * @return hooks array of hooks
     */
    function getHooks(address account) external view returns (address[] memory hooks) {
        // cache the storage config
        Config storage $config = $getConfig(account);

        // get the global hooks
        hooks = $config.globalHooks;
        // get the delegatecall hooks
        hooks.join($config.delegatecallHooks);
        // get the value hooks
        hooks.join($config.valueHooks);

        // cache the length of the sigs
        uint256 sigsLength = $config.sigs.length;
        // iterate over the sigs
        for (uint256 i; i < sigsLength; i++) {
            // get the sig hooks
            hooks.join($config.sigHooks[$config.sigs[i]]);
        }

        // cache the length of the target sigs
        uint256 targetSigsLength = $config.targetSigs.length;
        // iterate over the target sigs
        for (uint256 i; i < targetSigsLength; i++) {
            // get the target sig hooks
            hooks.join($config.targetSigHooks[$config.targetSigs[i]]);
        }

        // sort the hooks
        hooks.insertionSort();
        // uniquify the hooks
        hooks.uniquifySorted();
    }

    /**
     * Adds a hook to the account
     * @dev this function will not revert if the hook is already added
     *
     * @param hook address of the hook
     * @param hookType type of the hook
     */
    function addHook(address hook, HookType hookType) external {
        // cache the account
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        // check if the hook is attested to on the registry
        REGISTRY.checkForAccount({ smartAccount: account, module: hook, moduleType: TYPE_HOOK });

        if (hookType == HookType.GLOBAL) {
            // add the hook to the global hooks
            $getConfig(account).globalHooks.push(hook);
        } else if (hookType == HookType.DELEGATECALL) {
            // add the hook to the delegatecall hooks
            $getConfig(account).delegatecallHooks.push(hook);
        } else if (hookType == HookType.VALUE) {
            // add the hook to the value hooks
            $getConfig(account).valueHooks.push(hook);
        } else {
            revert UnsupportedHookType();
        }
    }

    /**
     * Adds a sig hook to the account
     * @dev this function will not revert if the hook is already added
     *
     * @param hook address of the hook
     * @param sig bytes4 of the sig
     * @param hookType type of the hook
     */
    function addSigHook(address hook, bytes4 sig, HookType hookType) external {
        // cache the account
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        // check if the hook is attested to on the registry
        REGISTRY.checkForAccount({ smartAccount: account, module: hook, moduleType: TYPE_HOOK });

        // cache the storage config
        Config storage $config = $getConfig(account);

        if (hookType == HookType.SIG) {
            // add the hook to the sig hooks
            $config.sigHooks[sig].push(hook);
            // add the sig to the sigs if it is not already added
            $config.sigs.pushUnique(sig);
        } else if (hookType == HookType.TARGET_SIG) {
            // add the hook to the target sig hooks
            $config.targetSigHooks[sig].push(hook);
            // add the sig to the target sigs if it is not already added
            $config.targetSigs.pushUnique(sig);
        } else {
            revert UnsupportedHookType();
        }
    }

    /**
     * Removes a hook from the account
     *
     * @param hook address of the hook
     * @param hookType type of the hook
     */
    function removeHook(address hook, HookType hookType) external {
        // cache the account
        address account = msg.sender;

        // cache the storage config
        Config storage $config = $getConfig(account);

        if (hookType == HookType.GLOBAL) {
            // delete the hook
            $config.globalHooks.popAddress(hook);
        } else if (hookType == HookType.DELEGATECALL) {
            // delete the hook
            $config.delegatecallHooks.popAddress(hook);
        } else if (hookType == HookType.VALUE) {
            // delete the hook
            $config.valueHooks.popAddress(hook);
        } else {
            revert UnsupportedHookType();
        }
    }

    /**
     * Removes a sig hook from the account
     *
     * @param hook address of the hook
     * @param sig bytes4 of the sig
     * @param hookType type of the hook
     */
    function removeSigHook(address hook, bytes4 sig, HookType hookType) external {
        // cache the account
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        // cache the storage config
        Config storage $config = $getConfig(account);

        if (hookType == HookType.SIG) {
            // get the length of the hooks for the same sig
            uint256 sigsHooksLength = $config.sigHooks[sig].length;
            // delete the hook
            $config.sigHooks[sig].popAddress(hook);

            // if there is only one hook for the sig, remove the sig
            if (sigsHooksLength == 1) {
                $config.targetSigs.popBytes4(sig);
            }
        } else if (hookType == HookType.TARGET_SIG) {
            // get the length of the hooks for the same sig
            uint256 targetSigsHooksLength = $config.targetSigHooks[sig].length;
            // delete the hook
            $config.targetSigHooks[sig].popAddress(hook);

            // if there is only one hook for the sig, remove the sig
            if (targetSigsHooksLength == 1) {
                $config.targetSigs.popBytes4(sig);
            }
        } else {
            revert UnsupportedHookType();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Checks if the transaction is valid
     * @dev this function is called before the transaction is executed
     *
     * @param msgSender address of the sender
     * @param msgValue value of the transaction
     * @param msgData data of the transaction
     *
     * @return hookData data of the hooks
     */
    function preCheck(
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    {
        // cache the storage config
        Config storage $config = $getConfig(msg.sender);
        // get the call data selector
        bytes4 callDataSelector = bytes4(msgData[:4]);

        // TODO: write tests for this. I think this breaks if globalHooks is empty
        // get the global and account sig hooks
        address[] memory hooks = $config.globalHooks;
        hooks.join($config.sigHooks[callDataSelector]);

        // if the hooked transaction is an execution, we need to check the value and the
        // targetSigHooks
        if (_isExecution(callDataSelector)) {
            // get the length of the execution callData
            uint256 paramLen = uint256(bytes32(msgData[EXEC_OFFSET - 32:EXEC_OFFSET]));

            // get the mode and calltype
            ModeCode mode = ModeCode.wrap(bytes32(msgData[4:36]));
            CallType calltype = ModeLib.getCallType(mode);

            if (calltype == CALLTYPE_SINGLE) {
                // decode the execution
                (, uint256 value, bytes calldata callData) =
                    ExecutionLib.decodeSingle(msgData[EXEC_OFFSET:EXEC_OFFSET + paramLen]);

                // if there is a value, we need to check the value hooks
                if (value != 0) {
                    hooks.join($config.valueHooks);
                }

                // if there is callData, we need to check the targetSigHooks
                if (callData.length > 4) {
                    hooks.join($config.targetSigHooks[bytes4(callData[:4])]);
                }
            } else if (calltype == CALLTYPE_BATCH) {
                // decode the batch
                hooks.join(
                    _getFromBatch({
                        $config: $config,
                        executions: ExecutionLib.decodeBatch(
                            msgData[EXEC_OFFSET:EXEC_OFFSET + paramLen]
                        )
                    })
                );
            } else if (calltype == CALLTYPE_DELEGATECALL) {
                // get the delegatecall hooks
                hooks.join($config.delegatecallHooks);
            }
        }

        // sort the hooks
        hooks.insertionSort();
        // uniquify the hooks
        hooks.uniquifySorted();

        // call all subhooks and return the subhooks with their context datas
        return abi.encode(
            hooks.preCheckSubHooks({ msgSender: msgSender, msgValue: msgValue, msgData: msgData })
        );
        // return abi.encode(
        //     hooks,
        //     hooks.preCheckSubHooks({ msgSender: msgSender, msgValue: msgValue, msgData: msgData
        // })
        // );
    }

    /**
     * Checks if the transaction is valid
     * @dev this function is called after the transaction is executed
     *
     * @param hookData data of the hooks
     */
    function postCheck(bytes calldata hookData) external override {
        // create the hooks and contexts array
        HookAndContext[] calldata hooksAndContexts;

        // decode the hookData
        // todo: optimise
        assembly ("memory-safe") {
            let dataPointer := add(hookData.offset, calldataload(hookData.offset))
            hooksAndContexts.offset := add(dataPointer, 0x20)
            hooksAndContexts.length := calldataload(dataPointer)
        }

        // get the length of the hooks
        uint256 length = hooksAndContexts.length;
        for (uint256 i; i < length; i++) {
            // cache the hook and context
            HookAndContext calldata hookAndContext = hooksAndContexts[i];
            // call postCheck on each hook
            hookAndContext.hook.postCheckSubHook({ preCheckContext: hookAndContext.context });
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Gets the hooks from the batch
     *
     * @param $config storage config
     * @param executions array of executions
     *
     * @return allHooks array of hooks
     */
    function _getFromBatch(
        Config storage $config,
        Execution[] calldata executions
    )
        internal
        view
        returns (address[] memory allHooks)
    {
        // check if the targetSigHooks are enabled
        bool targetSigHooksEnabled = $config.targetSigs.length != 0;
        // get the length of the executions
        uint256 length = executions.length;

        // casting bytes4 functionSigs in here. We are using uint256, since thats the native type
        // in LibSort
        uint256[] memory targetSigsInBatch = new uint256[](length);
        // variable to check if any of the executions have a value
        bool batchHasValue;
        // iterate over the executions
        for (uint256 i; i < length; i++) {
            // cache the execution
            Execution calldata execution = executions[i];
            // value only has to be checked once. If there is a value in any of the executions,
            // value hooks are used
            if (!batchHasValue && execution.value != 0) {
                // set the flag
                batchHasValue = true;
                // get the value hooks
                allHooks = $config.valueHooks;
                // If targetSigHooks are not enabled, we can stop here and return
                if (!targetSigHooksEnabled) return allHooks;
            }
            // if there is callData, we need to check the targetSigHooks
            if (execution.callData.length > 4) {
                targetSigsInBatch[i] = uint256(bytes32(execution.callData[:4]));
            }
        }
        // If targetSigHooks are not enabled, we can stop here and return
        if (!targetSigHooksEnabled) return allHooks;

        // we only want to sload the targetSigHooks once
        targetSigsInBatch.insertionSort();
        targetSigsInBatch.uniquifySorted();

        // cache the length of the targetSigsInBatch
        length = targetSigsInBatch.length;
        for (uint256 i; i < length; i++) {
            // downcast the functionSig to bytes4
            bytes4 targetSelector = bytes4(bytes32(targetSigsInBatch[i]));

            // get the targetSigHooks
            address[] storage _targetHooks = $config.targetSigHooks[targetSelector];

            // if there are none, continue
            if (_targetHooks.length == 0) continue;
            if (allHooks.length == 0) {
                // set the targetHooks if there are no other hooks
                allHooks = _targetHooks;
            } else {
                // join the targetHooks with the other hooks
                allHooks.join(_targetHooks);
            }
        }
    }

    /**
     * Checks if the callDataSelector is an execution
     *
     * @param callDataSelector bytes4 of the callDataSelector
     *
     * @return true if the callDataSelector is an execution, false otherwise
     */
    function _isExecution(bytes4 callDataSelector) internal pure returns (bool) {
        // check if the callDataSelector is an execution
        return callDataSelector == IERC7579Account.execute.selector
            || callDataSelector == IERC7579Account.executeFromExecutor.selector;
    }

    /**
     * Gets the config for the account
     *
     * @param account address of the account
     *
     * @return config storage config
     */
    function $getConfig(address account) internal view returns (Config storage) {
        return accountConfig[account];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Returns the type of the module
     *
     * @param typeID type of the module
     *
     * @return true if the type is a module type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure virtual override returns (bool) {
        return typeID == TYPE_HOOK;
    }

    /**
     * Returns the name of the module
     *
     * @return name of the module
     */
    function name() external pure virtual returns (string memory) {
        return "HookMultiPlexer";
    }

    /**
     * Returns the version of the module
     *
     * @return version of the module
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
