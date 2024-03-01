// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

type PermissionFlag is bytes32;

library PermissionFlagLib {
    function pack(
        bool permit_selfCall,
        bool permit_moduleCall,
        bool permit_sendValue,
        bool permit_erc20Transfer,
        bool permit_erc721Transfer,
        bool permit_hasAllowedFunctions,
        bool permit_hasAllowedTargets,
        bool permit_moduleConfig,
        bool enfoce_subhooks
    )
        internal
        pure
        returns (PermissionFlag)
    {
        return PermissionFlag.wrap(
            bytes32(
                uint256(
                    (permit_selfCall ? 1 : 0) + (permit_moduleCall ? 2 : 0)
                        + (permit_sendValue ? 4 : 0) + (permit_erc20Transfer ? 8 : 0)
                        + (permit_erc721Transfer ? 16 : 0) + (permit_hasAllowedFunctions ? 32 : 0)
                        + (permit_hasAllowedTargets ? 64 : 0) + (permit_moduleConfig ? 128 : 0)
                        + (enfoce_subhooks ? 256 : 0)
                )
            )
        );
    }

    function isSelfCall(PermissionFlag flags) internal pure returns (bool) {
        return uint256(PermissionFlag.unwrap(flags)) & 1 == 1;
    }

    function isModuleCall(PermissionFlag flags) internal pure returns (bool) {
        return uint256(PermissionFlag.unwrap(flags)) & 2 == 2;
    }

    function isSendValue(PermissionFlag flags) internal pure returns (bool) {
        return uint256(PermissionFlag.unwrap(flags)) & 4 == 4;
    }

    function isERC20Transfer(PermissionFlag flags) internal pure returns (bool) {
        return uint256(PermissionFlag.unwrap(flags)) & 8 == 8;
    }

    function isERC721Transfer(PermissionFlag flags) internal pure returns (bool) {
        return uint256(PermissionFlag.unwrap(flags)) & 16 == 16;
    }

    function hasAllowedFunctions(PermissionFlag flags) internal pure returns (bool) {
        return uint256(PermissionFlag.unwrap(flags)) & 32 == 32;
    }

    function hasAllowedTargets(PermissionFlag flags) internal pure returns (bool) {
        return uint256(PermissionFlag.unwrap(flags)) & 64 == 64;
    }

    function isModuleConfig(PermissionFlag flags) internal pure returns (bool) {
        return uint256(PermissionFlag.unwrap(flags)) & 128 == 128;
    }

    function enfoceSubhooks(PermissionFlag flags) internal pure returns (bool) {
        return uint256(PermissionFlag.unwrap(flags)) & 256 == 256;
    }
}
