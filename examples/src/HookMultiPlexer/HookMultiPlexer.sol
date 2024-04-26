// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579HookBase } from "modulekit/src/Modules.sol";
import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { SigHookInit, Config } from "./DataTypes.sol";
import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import {
    ModeLib, CallType, ModeCode, CALLTYPE_SINGLE, CALLTYPE_BATCH
} from "erc7579/lib/ModeLib.sol";
import { ExecutionLib, Execution } from "erc7579/lib/ExecutionLib.sol";
import { HookMultiPlexerLib } from "./HookMultiPlexerLib.sol";
import { LibSort } from "solady/utils/LibSort.sol";

uint256 constant EXEC_OFFSET = 100;

contract HookMultiPlexer is ERC7579HookBase {
    using HookMultiPlexerLib for address;
    using HookMultiPlexerLib for address[];
    using HookMultiPlexerLib for bytes4[];
    using LibSort for uint256[];
    using LibSort for address[];

    error HooksNotSorted();

    mapping(address account => Config config) internal accountConfig;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        Config storage $config = $getConfig(msg.sender);
        (
            address[] memory globalHooks,
            address[] memory valueHooks,
            SigHookInit[] memory sigHooks,
            SigHookInit[] memory targetSigHooks
        ) = abi.decode(data, (address[], address[], SigHookInit[], SigHookInit[]));

        if (!globalHooks.isSortedAndUniquified()) revert HooksNotSorted();
        if (!valueHooks.isSortedAndUniquified()) revert HooksNotSorted();

        $config.globalHooks = globalHooks;
        $config.valueHooks = valueHooks;

        uint256 length = sigHooks.length;
        for (uint256 i; i < length; i++) {
            bytes4 hookForSig = sigHooks[i].sig;
            if (!sigHooks[i].subHooks.isSortedAndUniquified()) revert HooksNotSorted();
            $config.sigHooks[hookForSig] = sigHooks[i].subHooks;
        }

        length = targetSigHooks.length;
        for (uint256 i; i < length; i++) {
            bytes4 hookForSig = targetSigHooks[i].sig;

            if (!targetSigHooks[i].subHooks.isSortedAndUniquified()) revert HooksNotSorted();
            $config.targetSigHooksEnabled = true;
            $config.targetSigHooks[hookForSig] = targetSigHooks[i].subHooks;
        }
    }

    function onUninstall(bytes calldata) external override { }

    function isInitialized(address smartAccount) public view returns (bool) { }

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

        address[] memory hooks = $config.globalHooks.join($config.sigHooks[callDataSelector]);

        if (
            callDataSelector == IERC7579Account.execute.selector
                || callDataSelector == IERC7579Account.executeFromExecutor.selector
        ) {
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
            }
        }

        hooks.insertionSort();
        hooks.uniquifySorted();

        return abi.encode(hooks, hooks.preCheckSubHooks(msgSender, msgValue, msgData));
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
            hooks[i].postCheckSubHook(contexts[i]);
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
        bool targetSigHooksEnabled = $config.targetSigHooksEnabled;
        uint256 length = executions.length;
        uint256[] memory targetSigsInBatch = new uint256[](length);
        bool batchHasValue;
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];
            if (!batchHasValue && execution.value != 0) {
                batchHasValue = true;
                allHooks = $config.valueHooks;
                if (!targetSigHooksEnabled) return allHooks;
            }
            targetSigsInBatch[i] = uint256(bytes32(execution.callData[:4]));
        }
        if (targetSigHooksEnabled) return allHooks;
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
