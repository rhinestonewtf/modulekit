// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579HookBase, ERC7484RegistryAdapter } from "modulekit/src/Modules.sol";
import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { SigHookInit, Config, HookType } from "./DataTypes.sol";
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
import { HookMultiplexerLib } from "./HookMultiplexerLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { IERC7484 } from "modulekit/src/interfaces/IERC7484.sol";

uint256 constant EXEC_OFFSET = 100;

contract HookMultiplexer is ERC7579HookBase, ERC7484RegistryAdapter {
    using HookMultiplexerLib for *;
    using LibSort for uint256[];
    using LibSort for address[];

    mapping(address account => Config config) internal accountConfig;

    constructor(IERC7484 _registry) ERC7484RegistryAdapter(_registry) { }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        (
            address[] calldata globalHooks,
            address[] calldata valueHooks,
            address[] calldata delegatecallHooks,
            SigHookInit[] calldata sigHooks,
            SigHookInit[] calldata targetSigHooks
        ) = data.decodeOnInstall();

        Config storage $config = $getConfig(msg.sender);
        globalHooks.requireSortedAndUnique();
        valueHooks.requireSortedAndUnique();

        // todo check registry for hooks?

        $config.globalHooks = globalHooks;
        $config.delegatecallHooks = delegatecallHooks;
        $config.valueHooks = valueHooks;

        uint256 length = sigHooks.length;
        uint256[] memory sigs = new uint256[](length);
        for (uint256 i; i < length; i++) {
            SigHookInit calldata _sigHook = sigHooks[i];
            _sigHook.subHooks.requireSortedAndUnique();
            sigs[i] = uint256(bytes32(_sigHook.sig));
            $config.sigHooks[_sigHook.sig] = _sigHook.subHooks;
        }

        sigs.insertionSort();
        sigs.uniquifySorted();

        length = sigs.length;
        for (uint256 i; i < length; i++) {
            $config.sigs.push(bytes4(bytes32(sigs[i])));
        }

        length = targetSigHooks.length;
        uint256[] memory targetSigs = new uint256[](length);
        for (uint256 i; i < length; i++) {
            SigHookInit calldata _targetSigHook = targetSigHooks[i];
            _targetSigHook.subHooks.requireSortedAndUnique();
            targetSigs[i] = uint256(bytes32(_targetSigHook.sig));
            $config.targetSigHooks[_targetSigHook.sig] = _targetSigHook.subHooks;
        }

        targetSigs.insertionSort();
        targetSigs.uniquifySorted();

        length = targetSigs.length;
        for (uint256 i; i < length; i++) {
            $config.targetSigs.push(bytes4(bytes32(targetSigs[i])));
        }
    }

    function onUninstall(bytes calldata) external override {
        Config storage $config = $getConfig(msg.sender);

        delete $config.globalHooks;
        delete $config.delegatecallHooks;
        delete $config.valueHooks;

        uint256 length = $config.sigs.length;
        for (uint256 i; i < length; i++) {
            delete $config.sigHooks[$config.sigs[i]];
        }
        delete $config.sigs;

        length = $config.targetSigs.length;
        for (uint256 i; i < length; i++) {
            delete $config.targetSigHooks[$config.targetSigs[i]];
        }
        delete $config.targetSigs;
    }

    function isInitialized(address smartAccount) public view returns (bool) {
        Config storage $config = $getConfig(msg.sender);
        return $config.globalHooks.length != 0 || $config.delegatecallHooks.length != 0
            || $config.valueHooks.length != 0 || $config.sigs.length != 0
            || $config.targetSigs.length != 0;
    }

    function getHooks(address account) external view returns (address[] memory hooks) {
        Config storage $config = $getConfig(msg.sender);

        hooks = $config.globalHooks.join($config.delegatecallHooks);
        hooks.join($config.valueHooks);

        uint256 sigsLength = $config.sigs.length;
        for (uint256 i; i < sigsLength; i++) {
            hooks.join($config.sigHooks[$config.sigs[i]]);
        }

        uint256 targetSigsLength = $config.targetSigs.length;
        for (uint256 i; i < targetSigsLength; i++) {
            hooks.join($config.targetSigHooks[$config.targetSigs[i]]);
        }

        hooks.insertionSort();
        hooks.uniquifySorted();
    }

    function addHook(address hook, HookType hookType) external {
        // cache the account
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        REGISTRY.checkForAccount({ smartAccount: account, module: hook, moduleType: TYPE_HOOK });

        if (hookType == HookType.GLOBAL) {
            $getConfig(account).globalHooks.push(hook);
        } else if (hookType == HookType.DELEGATECALL) {
            $getConfig(account).delegatecallHooks.push(hook);
        } else if (hookType == HookType.VALUE) {
            $getConfig(account).valueHooks.push(hook);
        }
    }

    function addSigHook(address hook, bytes4 sig, HookType hookType) external {
        // cache the account
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        REGISTRY.checkForAccount({ smartAccount: account, module: hook, moduleType: TYPE_HOOK });

        Config storage $config = $getConfig(account);

        if (hookType == HookType.SIG) {
            $config.sigHooks[sig].push(hook);
            $config.sigs.pushUnique(sig);
        } else if (hookType == HookType.TARGET_SIG) {
            $config.targetSigHooks[sig].push(hook);
            $config.targetSigs.pushUnique(sig);
        }
    }

    function removeHook(address hook, HookType hookType) external {
        // cache the account
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        Config storage $config = $getConfig(account);

        if (hookType == HookType.GLOBAL) {
            uint256 index = $config.globalHooks.indexOf(hook);
            delete $config.globalHooks[index];
        } else if (hookType == HookType.DELEGATECALL) {
            uint256 index = $config.delegatecallHooks.indexOf(hook);
            delete $config.delegatecallHooks[index];
        } else if (hookType == HookType.VALUE) {
            uint256 index = $config.valueHooks.indexOf(hook);
            delete $config.valueHooks[index];
        }
    }

    function removeSigHook(address hook, bytes4 sig, HookType hookType) external {
        // cache the account
        address account = msg.sender;
        // check if the module is initialized and revert if it is not
        if (!isInitialized(account)) revert NotInitialized(account);

        Config storage $config = $getConfig(account);

        if (hookType == HookType.SIG) {
            uint256 index = $config.sigHooks[sig].indexOf(hook);
            uint256 sigsHooksLength = $config.sigHooks[sig].length;
            delete $config.sigHooks[sig][index];

            if (sigsHooksLength == 1) {
                $config.targetSigs.popUnique(sig);
            }
        } else if (hookType == HookType.TARGET_SIG) {
            uint256 index = $config.targetSigHooks[sig].indexOf(hook);
            uint256 targetSigsHooksLength = $config.targetSigHooks[sig].length;
            delete $config.targetSigHooks[sig][index];

            if (targetSigsHooksLength == 1) {
                $config.targetSigs.popUnique(sig);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

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
        Config storage $config = $getConfig(msg.sender);

        bytes4 callDataSelector = bytes4(msgData[:4]);

        // TODO: write tests for this. I think this breaks if globalHooks is empty
        address[] memory hooks = $config.globalHooks.join($config.sigHooks[callDataSelector]);

        // if the hooked transaction is an execution, we need to check the value and the
        // targetSigHooks
        if (_isExecution(callDataSelector)) {
            uint256 paramLen = uint256(bytes32(msgData[EXEC_OFFSET - 32:EXEC_OFFSET]));

            ModeCode mode = ModeCode.wrap(bytes32(msgData[4:36]));
            CallType calltype = ModeLib.getCallType(mode);

            if (calltype == CALLTYPE_SINGLE) {
                (, uint256 value, bytes calldata callData) =
                    ExecutionLib.decodeSingle(msgData[EXEC_OFFSET:EXEC_OFFSET + paramLen]);
                if (value != 0) {
                    hooks.join($config.valueHooks);
                }
                hooks.join($config.targetSigHooks[bytes4(callData[:4])]);
            } else if (calltype == CALLTYPE_BATCH) {
                hooks.join(
                    _getFromBatch({
                        $config: $config,
                        executions: ExecutionLib.decodeBatch(
                            msgData[EXEC_OFFSET:EXEC_OFFSET + paramLen]
                        )
                    })
                );
            } else if (calltype == CALLTYPE_DELEGATECALL) {
                hooks.join($config.delegatecallHooks);
            }
        }

        hooks.insertionSort();
        hooks.uniquifySorted();

        // call all subhooks and get the subhook context datas
        return abi.encode(
            hooks,
            hooks.preCheckSubHooks({ msgSender: msgSender, msgValue: msgValue, msgData: msgData })
        );
    }

    function postCheck(bytes calldata hookData) external {
        address[] calldata hooks;
        bytes[] calldata contexts;

        assembly ("memory-safe") {
            let offset := hookData.offset
            let baseOffset := offset

            let dataPointer := add(baseOffset, calldataload(offset))
            hooks.offset := add(dataPointer, 0x20)
            hooks.length := calldataload(dataPointer)
            offset := add(offset, 0x20)

            dataPointer := add(baseOffset, calldataload(offset))
            contexts.offset := add(dataPointer, 0x20)
            contexts.length := calldataload(dataPointer)
        }

        uint256 length = hooks.length;

        for (uint256 i; i < length; i++) {
            hooks[i].postCheckSubHook({ preCheckContext: contexts[i] });
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getFromBatch(
        Config storage $config,
        Execution[] calldata executions
    )
        internal
        view
        returns (address[] memory allHooks)
    {
        bool targetSigHooksEnabled = $config.targetSigs.length != 0;
        uint256 length = executions.length;

        // casting bytes4  functionSigs in here. We are using uint256, since thats the native type
        // in LibSort
        uint256[] memory targetSigsInBatch = new uint256[](length);
        bool batchHasValue;
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];
            // value only has to be checked once. If there is a value in any of the executions,
            // value hooks are used
            if (!batchHasValue && execution.value != 0) {
                batchHasValue = true;
                allHooks = $config.valueHooks;
                // If targetSigHooks are not enabled, we can stop here and return
                if (!targetSigHooksEnabled) return allHooks;
            }
            targetSigsInBatch[i] = uint256(bytes32(execution.callData[:4]));
        }
        // If targetSigHooks are not enabled, we can stop here and return
        if (targetSigHooksEnabled) return allHooks;

        // we only want to sload the targetSigHooks once
        targetSigsInBatch.insertionSort();
        targetSigsInBatch.uniquifySorted();

        length = targetSigsInBatch.length;
        for (uint256 i; i < length; i++) {
            bytes4 targetSelector = bytes4(bytes32(targetSigsInBatch[i]));

            address[] storage _targetHook = $config.targetSigHooks[targetSelector];
            if (_targetHook.length == 0) continue;
            if (allHooks.length == 0) {
                allHooks = _targetHook;
            } else {
                allHooks.join(_targetHook);
            }
        }
    }

    function _isExecution(bytes4 callDataSelector) internal pure returns (bool) {
        return callDataSelector == IERC7579Account.execute.selector
            || callDataSelector == IERC7579Account.executeFromExecutor.selector;
    }

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
        return "HookMultiplexer";
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
