// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";
import { Execution } from "modulekit/src/modules/ERC7579HookDestruct.sol";
import "./DataTypes.sol";

library HookMultiPlexerLib {
    error SubHookPreCheckError(IERC7579Hook subHook);
    error SubHookPostCheckError(IERC7579Hook subHook);

    function preCheckSubHooks(
        IERC7579Hook[] storage subHooks,
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        returns (PreCheckContext[] memory contexts)
    {
        uint256 length = subHooks.length;
        contexts = new PreCheckContext[](length);
        for (uint256 i; i < length; i++) {
            IERC7579Hook _subHook = subHooks[i];
            contexts[i] = PreCheckContext({
                subHook: _subHook,
                context: preCheckSubHook(_subHook, msgSender, msgValue, msgData)
            });
        }
    }

    function preCheckSubHook(
        IERC7579Hook subHook,
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        returns (bytes memory preCheckContext)
    {
        bool success;
        (success, preCheckContext) = address(subHook).call(
            abi.encodePacked(
                abi.encodeCall(IERC7579Hook.preCheck, (msgSender, msgValue, msgData)),
                address(this),
                msg.sender
            )
        );
        if (!success) revert SubHookPreCheckError(subHook);
    }

    function postCheckSubHook(IERC7579Hook subHook, bytes calldata preCheckContext) internal {
        (bool success,) = address(subHook).call(packERC2771(preCheckContext));
        if (!success) revert SubHookPostCheckError(subHook);
    }

    function packERC2771(bytes calldata preCheckContext)
        private
        view
        returns (bytes memory packed)
    {
        return abi.encodePacked(preCheckContext, address(this), msg.sender);
    }
}
