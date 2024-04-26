// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";
import { SigHookInit } from "./DataTypes.sol";
import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";

library HookMultiplexerLib {
    error SubHookPreCheckError(address subHook);
    error SubHookPostCheckError(address subHook);
    error HooksNotSorted();

    function preCheckSubHooks(
        address[] memory subHooks,
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        returns (bytes[] memory contexts)
    {
        uint256 length = subHooks.length;
        contexts = new bytes[](length);
        for (uint256 i; i < length; i++) {
            address _subHook = subHooks[i];
            contexts[i] = preCheckSubHook(_subHook, msgSender, msgValue, msgData);
        }
    }

    function preCheckSubHook(
        address subHook,
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

    function postCheckSubHook(address subHook, bytes calldata preCheckContext) internal {
        (bool success,) = address(subHook).call(packERC2771(preCheckContext));
        if (!success) revert SubHookPostCheckError(subHook);
    }

    function packERC2771(bytes memory preCheckContext) private view returns (bytes memory packed) {
        return abi.encodePacked(
            IERC7579Hook.postCheck.selector, preCheckContext, address(this), msg.sender
        );
    }

    function join(
        address[] memory a,
        address[] memory b
    )
        internal
        pure
        returns (address[] memory c)
    {
        uint256 aLength = a.length;
        uint256 bLength = b.length;
        uint256 totalLength = aLength + bLength;
        assembly ("memory-safe") {
            c := a
            mstore(c, totalLength)
        }
        for (uint256 i; i < bLength; i++) {
            c[aLength + i] = b[i];
        }
    }

    function requireSortedAndUnique(address[] calldata array) internal pure {
        uint256 length = array.length;
        for (uint256 i = 1; i < length; i++) {
            if (array[i - 1] >= array[i]) {
                revert HooksNotSorted();
            }
        }
    }

    function decodeOnInstall(bytes calldata onInstallData)
        internal
        pure
        returns (
            address[] calldata globalHooks,
            address[] calldata valueHooks,
            address[] calldata delegatecallHooks,
            SigHookInit[] calldata sigHooks,
            SigHookInit[] calldata targetSigHooks
        )
    {
        // saves 2000 gas when 1 hook per type used
        // (
        //     address[] memory globalHooks,
        //     address[] memory valueHooks,
        //     address[] memory delegatecallHooks,
        //     SigHookInit[] memory sigHooks,
        //     SigHookInit[] memory targetSigHooks
        // ) = abi.decode(data, (address[], address[], address[], SigHookInit[], SigHookInit[]));
        assembly ("memory-safe") {
            let offset := onInstallData.offset
            let baseOffset := offset

            let dataPointer := add(baseOffset, calldataload(offset))
            globalHooks.offset := add(dataPointer, 0x20)
            globalHooks.length := calldataload(dataPointer)
            offset := add(offset, 0x20)

            dataPointer := add(baseOffset, calldataload(offset))
            valueHooks.offset := add(dataPointer, 0x20)
            valueHooks.length := calldataload(dataPointer)
            offset := add(offset, 0x20)

            dataPointer := add(baseOffset, calldataload(offset))
            delegatecallHooks.offset := add(dataPointer, 0x20)
            delegatecallHooks.length := calldataload(dataPointer)
            offset := add(offset, 0x20)

            dataPointer := add(baseOffset, calldataload(offset))
            sigHooks.offset := add(dataPointer, 0x20)
            sigHooks.length := calldataload(dataPointer)
            offset := add(offset, 0x20)

            dataPointer := add(baseOffset, calldataload(offset))
            targetSigHooks.offset := add(dataPointer, 0x20)
            targetSigHooks.length := calldataload(dataPointer)
        }
    }
}
