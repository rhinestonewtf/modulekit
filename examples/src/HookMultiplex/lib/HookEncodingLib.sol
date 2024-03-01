// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../IHookMultiplexer.sol";
import "forge-std/console2.sol";

library HookEncodingLib {
    function pack(IHookMultiPlexer.ConfigParam calldata params)
        internal
        pure
        returns (bytes32 encoded)
    {
        return
            encode(params.hook, params.isExecutorHook, params.isValidatorHook, params.isConfigHook);
    }

    function encode(
        address hook,
        hookFlag isExecutorHook,
        hookFlag isValidatorHook,
        hookFlag isConfigHook
    )
        internal
        pure
        returns (bytes32 encoded)
    {
        assembly {
            encoded := hook
            encoded := or(encoded, shl(8, isExecutorHook))
            encoded := or(encoded, shl(16, isValidatorHook))
            encoded := or(encoded, shl(24, isConfigHook))
        }
        encoded = bytes32(
            (abi.encodePacked(isExecutorHook, isValidatorHook, isConfigHook, bytes5(0), hook))
        );
    }

    function decode(bytes32 encoded)
        internal
        pure
        returns (
            address hook,
            hookFlag isExecutorHook,
            hookFlag isValidatorHook,
            hookFlag isConfigHook
        )
    {
        assembly {
            hook := encoded
            isExecutorHook := shr(8, encoded)
            isValidatorHook := shr(16, encoded)
            isConfigHook := shr(24, encoded)
        }
    }

    function isExecutorHook(bytes32 encoded) internal pure returns (bool) {
        return (uint256(encoded)) & 0xff == 1;
    }

    function is4337Hook(bytes32 encoded) internal pure returns (bool) {
        return (uint256(encoded) >> 8) & 0xff == 1;
    }

    function isConfigHook(bytes32 encoded) internal pure returns (bool) {
        return (uint256(encoded) >> 16) & 0xff == 1;
    }

    function decodeAddress(bytes32 encoded) internal pure returns (address) {
        return address(uint160(uint256(encoded)));
    }
}
