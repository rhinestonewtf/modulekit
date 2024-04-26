// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579HookBase } from "modulekit/src/Modules.sol";
import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { AllContext, SigHookInit, PreCheckContext, Config } from "./DataTypes.sol";
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

        // TODO: check if sorted

        $config.globalHooks = globalHooks;
        $config.valueHooks = valueHooks;

        uint256 length = sigHooks.length;
        for (uint256 i; i < length; i++) {
            bytes4 hookForSig = sigHooks[i].sig;
            $config.sigHooks[hookForSig] = sigHooks[i].subHooks;
        }

        length = targetSigHooks.length;
        for (uint256 i; i < length; i++) {
            bytes4 hookForSig = targetSigHooks[i].sig;
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
                address[] memory targetSigHooks = _getTargetSig(
                    $config,
                    ExecutionLib.decodeBatch(msgData[EXEC_OFFSET:EXEC_OFFSET + paramLen]),
                    msgSender,
                    msgData
                );
                hooks.join(targetSigHooks);
            }
        }

        hooks.insertionSort();
        hooks.uniquifySorted();

        return abi.encode(hooks, hooks.preCheckSubHooks(msgSender, msgValue, msgData));
    }
    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getTargetSig(
        Config storage $config,
        Execution[] calldata executions,
        address msgSender,
        bytes calldata msgData
    )
        internal
        returns (address[] memory allHooks)
    {
        uint256 length = executions.length;
        uint256[] memory targetSigsInBatch = new uint256[](length);
        bool batchHasValue;
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];
            targetSigsInBatch[i] = uint256(bytes32(execution.callData[:4]));
        }
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

    function postCheck(bytes calldata hookData) external {
        (address[] memory hooks, bytes[] memory contexs) =
            abi.decode(hookData, (address[], bytes[]));

        uint256 length = hooks.length;

        for (uint256 i; i < length; i++) {
            hooks[i].postCheckSubHook(contexs[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    // function _getTargetSig(
    //     Execution[] calldata executions,
    //     address msgSender,
    //     bytes calldata msgData
    // )
    //     internal
    //     returns (PreCheckContext[][] memory targetSigHooks, PreCheckContext[] memory valueHooks)
    // {
    //     uint256 length = executions.length;
    //
    //     uint256[] memory uniqueSigs = new uint256[](length);
    //     bool hasValue;
    //     for (uint256 i; i < length; i++) {
    //         Execution calldata execution = executions[i];
    //         uniqueSigs[i] = uint256(bytes32(bytes4(execution.callData[:4])));
    //         if (!hasValue && execution.value != 0) {
    //             hasValue = true;
    //             valueHooks =
    //                 $getConfig(msg.sender).valueHooks.preCheckSubHooks(msgSender, 0, msgData);
    //         }
    //     }
    //     uniqueSigs.sort();
    //     uniqueSigs.uniquifySorted();
    //
    //     length = uniqueSigs.length;
    //     targetSigHooks = new PreCheckContext[][](length);
    //
    //     for (uint256 i; i < length; i++) {
    //         bytes4 targetSelector = bytes4(bytes32(uniqueSigs[i]));
    //         targetSigHooks[i] = $getConfig(msg.sender).targetSigHooks[targetSelector]
    //             .preCheckSubHooks(msgSender, 0, msgData);
    //     }
    // }

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
