// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";
import { SigHookInit, HookAndContext } from "./DataTypes.sol";
import { IERC7579Hook } from "modulekit/src/external/ERC7579.sol";

/**
 * @title HookMultiPlexerLib
 * @dev Library for multiplexing hooks
 * @author Rhinestone
 */
library HookMultiPlexerLib {
    error SubHookPreCheckError(address subHook);
    error SubHookPostCheckError(address subHook);
    error HooksNotSorted();

    /**
     * Prechecks a list of subhooks
     *
     * @param subHooks array of sub-hooks
     * @param msgSender sender of the transaction
     * @param msgValue value of the transaction
     * @param msgData data of the transaction
     *
     * @return hookAndContexts array of hook and context
     */
    function preCheckSubHooks(
        address[] memory subHooks,
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        returns (HookAndContext[] memory hookAndContexts)
    {
        // cache the length of the subhooks
        uint256 length = subHooks.length;
        // initialize the contexts array
        hookAndContexts = new HookAndContext[](length);
        for (uint256 i; i < length; i++) {
            // cache the subhook
            address subHook = subHooks[i];
            // precheck the subhook and return the context
            hookAndContexts[i] = HookAndContext({
                hook: subHook,
                context: preCheckSubHook(subHook, msgSender, msgValue, msgData)
            });
        }
    }

    /**
     * Prechecks a single subhook
     *
     * @param subHook sub-hook
     * @param msgSender sender of the transaction
     * @param msgValue value of the transaction
     * @param msgData data of the transaction
     *
     * @return preCheckContext pre-check context
     */
    function preCheckSubHook(
        address subHook,
        address msgSender,
        uint256 msgValue,
        bytes calldata msgData
    )
        internal
        returns (bytes memory preCheckContext)
    {
        // precheck the subhook
        bool success;
        (success, preCheckContext) = address(subHook).call(
            abi.encodePacked(
                abi.encodeCall(IERC7579Hook.preCheck, (msgSender, msgValue, msgData)),
                address(this),
                msg.sender
            )
        );
        // revert if the subhook precheck fails
        if (!success) revert SubHookPreCheckError(subHook);
    }

    /**
     * Postchecks a single subhook
     *
     * @param subHook sub-hook
     * @param preCheckContext pre-check context
     */
    function postCheckSubHook(address subHook, bytes calldata preCheckContext) internal {
        bytes memory data = abi.encodePacked(
            IERC7579Hook.postCheck.selector, preCheckContext, address(this), msg.sender
        );
        // postcheck the subhook
        (bool success,) = address(subHook).call(data);
        // revert if the subhook postcheck fails
        if (!success) revert SubHookPostCheckError(subHook);
    }

    /**
     * Joins two arrays
     *
     * @param a first array
     * @param b second array
     */
    function join(address[] memory a, address[] memory b) internal pure {
        // cache the lengths of the arrays
        uint256 aLength = a.length;
        uint256 bLength = b.length;
        uint256 totalLength = aLength + bLength;

        // if both arrays are empty, return an empty array
        if (totalLength == 0) {
            return;
        } else if (bLength == 0) {
            return;
        }

        // initialize the joined array
        uint256 offset;
        assembly {
            mstore(a, totalLength)
            offset := add(b, 0x20)
        }

        for (uint256 i; i < bLength; i++) {
            // join the arrays
            address next;
            assembly {
                next := mload(add(offset, mul(i, 0x20)))
            }
            a[aLength + i] = next;
        }
    }

    /**
     * Ensures that an array is sorted and unique
     *
     * @param array array to check
     */
    function requireSortedAndUnique(address[] calldata array) internal pure {
        // cache the length of the array
        uint256 length = array.length;
        for (uint256 i = 1; i < length; i++) {
            // revert if the array is not sorted
            if (array[i - 1] >= array[i]) {
                revert HooksNotSorted();
            }
        }
    }

    /**
     * Gets the index of an element in an array
     *
     * @param array array to search
     * @param element element to find
     *
     * @return index index of the element
     */
    function indexOf(address[] storage array, address element) internal view returns (uint256) {
        // cache the length of the array
        uint256 length = array.length;
        for (uint256 i; i < length; i++) {
            // return the index of the element
            if (array[i] == element) {
                return i;
            }
        }
        // return the maximum value if the element is not found
        return type(uint256).max;
    }

    /**
     * Gets the index of an element in an array
     *
     * @param array array to search
     * @param element element to find
     *
     * @return index index of the element
     */
    function indexOf(bytes4[] storage array, bytes4 element) internal view returns (uint256) {
        // cache the length of the array
        uint256 length = array.length;
        for (uint256 i; i < length; i++) {
            // return the index of the element
            if (array[i] == element) {
                return i;
            }
        }
        // return the maximum value if the element is not found
        return type(uint256).max;
    }

    /**
     * Pushes a unique element to an array
     *
     * @param array array to push to
     * @param element element to push
     */
    function pushUnique(bytes4[] storage array, bytes4 element) internal {
        // cache the length of the array
        uint256 index = indexOf(array, element);
        if (index == type(uint256).max) {
            array.push(element);
        }
    }

    /**
     * Pops a bytes4 element from an array
     *
     * @param array array to pop from
     * @param element element to pop
     */
    function popBytes4(bytes4[] storage array, bytes4 element) internal {
        uint256 index = indexOf(array, element);
        if (index == type(uint256).max) {
            return;
        }
        array[index] = array[array.length - 1];
        array.pop();
    }

    /**
     * Pops an address from an array
     *
     * @param array array to pop from
     * @param element element to pop
     */
    function popAddress(address[] storage array, address element) internal {
        uint256 index = indexOf(array, element);
        if (index == type(uint256).max) {
            return;
        }
        array[index] = array[array.length - 1];
        array.pop();
    }

    /**
     * Decodes the onInstall data
     *
     * @param onInstallData onInstall data
     *
     * @return globalHooks array of global hooks
     * @return valueHooks array of value hooks
     * @return delegatecallHooks array of delegatecall hooks
     * @return sigHooks array of sig hooks
     * @return targetSigHooks array of target sig hooks
     */
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
