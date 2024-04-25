// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import "./DataTypes.sol";
import { Execution } from "modulekit/src/modules/ERC7579HookDestruct.sol";

import { HookMultiPlexerLib } from "./HookMultiPlexerLib.sol";
import "forge-std/console2.sol";

contract HookMultiPlexerBase {
    using HookMultiPlexerLib for IERC7579Hook[];

    mapping(address account => Config config) internal accountConfig;

    function $getConfig(address account) internal view returns (Config storage) {
        return accountConfig[account];
    }

    function _handleSingle(
        bytes4 execSig,
        address msgSender,
        uint256 value,
        bytes calldata msgData
    )
        internal
        returns (bytes memory context)
    {
        Config storage $config = $getConfig(msg.sender);

        AllContext memory _context;
        _context.globalHooks = $config.globalHooks.preCheckSubHooks(msgSender, 0, msgData);
        _context.sigHooks = $config.sigHooks[execSig].preCheckSubHooks(msgSender, 0, msgData);

        if (value != 0) {
            _context.valueHooks = $config.valueHooks.preCheckSubHooks(msgSender, 0, msgData);
        }

        context = abi.encode(_context);
    }

    function _handleBatch(
        bytes4 execSig,
        address msgSender,
        Execution[] calldata executions,
        bytes calldata msgData
    )
        internal
        returns (bytes memory context)
    {
        Config storage $config = $getConfig(msg.sender);

        AllContext memory _context;
        _context.globalHooks = $config.globalHooks.preCheckSubHooks(msgSender, 0, msgData);
        _context.sigHooks = $config.sigHooks[execSig].preCheckSubHooks(msgSender, 0, msgData);
        (_context.targetSigHooks) = _getTargetSig(msgSender, executions, msgData);

        context = abi.encode(_context);
    }

    function _getTargetSig(
        address msgSender,
        Execution[] calldata executions,
        bytes calldata msgData
    )
        internal
        returns (PreCheckContext[][] memory targetSigHooks)
    {
        uint256 length = executions.length;
        targetSigHooks = new PreCheckContext[][](length);
        // bool hasValue;
        bytes32 sigXor;
        uint256 uniqueSigs;
        for (uint256 i; i < length; i++) {
            Execution calldata execution = executions[i];
            bytes4 targetSelector = bytes4(execution.callData[:4]);
            bytes32 _sigHash = bytes32(keccak256(abi.encodePacked(targetSelector)));
            bytes32 xor = sigXor ^ _sigHash;
            if (xor != bytes32(0)) {
                targetSigHooks[uniqueSigs] = $getConfig(msg.sender).targetSigHooks[targetSelector]
                    .preCheckSubHooks(msgSender, 0, msgData);

                sigXor ^= xor;
                uniqueSigs++;
            }
        }

        assembly {
            mstore(targetSigHooks, uniqueSigs)
        }
    }
}
