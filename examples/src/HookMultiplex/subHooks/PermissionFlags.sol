// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SentinelListLib, SENTINEL as SENTINEL_ADDRESS } from "sentinellist/SentinelList.sol";
import {
    LinkedBytes32Lib, SENTINEL as SENTINEL_BYTES32
} from "sentinellist/SentinelListBytes32.sol";
import { SSTORE2 } from "solady/src/utils/SSTORE2.sol";
import { Execution } from "@rhinestone/modulekit/src/Accounts.sol";
import { SubHookBase } from "./SubHookBase.sol";
import { TokenTransactionLib } from "../lib/TokenTransactionLib.sol";
import "forge-std/console2.sol";

// bytes32 constant STORAGE_SLOT = keccak256("permissions.storage");
bytes32 constant STORAGE_SLOT = bytes32(uint256(123));

type PermissionFlags is bytes32;

library PermissionFlagsLib {
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
        returns (PermissionFlags)
    {
        return PermissionFlags.wrap(
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

    function isSelfCall(PermissionFlags flags) internal pure returns (bool) {
        return uint256(PermissionFlags.unwrap(flags)) & 1 == 1;
    }

    function isModuleCall(PermissionFlags flags) internal pure returns (bool) {
        return uint256(PermissionFlags.unwrap(flags)) & 2 == 2;
    }

    function isSendValue(PermissionFlags flags) internal pure returns (bool) {
        return uint256(PermissionFlags.unwrap(flags)) & 4 == 4;
    }

    function isERC20Transfer(PermissionFlags flags) internal pure returns (bool) {
        return uint256(PermissionFlags.unwrap(flags)) & 8 == 8;
    }

    function isERC721Transfer(PermissionFlags flags) internal pure returns (bool) {
        return uint256(PermissionFlags.unwrap(flags)) & 16 == 16;
    }

    function hasAllowedFunctions(PermissionFlags flags) internal pure returns (bool) {
        return uint256(PermissionFlags.unwrap(flags)) & 32 == 32;
    }

    function hasAllowedTargets(PermissionFlags flags) internal pure returns (bool) {
        return uint256(PermissionFlags.unwrap(flags)) & 64 == 64;
    }

    function isModuleConfig(PermissionFlags flags) internal pure returns (bool) {
        return uint256(PermissionFlags.unwrap(flags)) & 128 == 128;
    }

    function enfoceSubhooks(PermissionFlags flags) internal pure returns (bool) {
        return uint256(PermissionFlags.unwrap(flags)) & 256 == 256;
    }
}

contract PermissionHook is SubHookBase {
    using SentinelListLib for SentinelListLib.SentinelList;
    using LinkedBytes32Lib for LinkedBytes32Lib.LinkedBytes32;
    using TokenTransactionLib for bytes4;
    using PermissionFlagsLib for PermissionFlags;

    error InvalidPermission();

    struct ConfigParams {
        PermissionFlags flags;
        address[] allowedTargets;
        bytes4[] allowedFunctions;
    }

    struct ModulePermissions {
        PermissionFlags flags;
        LinkedBytes32Lib.LinkedBytes32 allowedFunctions;
        SentinelListLib.SentinelList allowedTargets;
    }

    struct SubHookStorage {
        mapping(address account => mapping(address module => ModulePermissions)) permissions;
    }

    constructor(address HookMultiplexer) SubHookBase(HookMultiplexer) { }

    function $subHook() internal pure virtual returns (SubHookStorage storage shs) {
        bytes32 position = STORAGE_SLOT;
        assembly {
            shs.slot := position
        }
    }

    function getPermissions(
        address account,
        address module
    )
        external
        view
        returns (ConfigParams memory config)
    {
        (address[] memory allowedTargets,) = $subHook().permissions[account][module]
            .allowedTargets
            .getEntriesPaginated(SENTINEL_ADDRESS, 100);
        (bytes32[] memory _allowedFunctions,) = $subHook().permissions[account][module]
            .allowedFunctions
            .getEntriesPaginated(SENTINEL_BYTES32, 100);
        bytes4[] memory allowedFunctions = new bytes4[](_allowedFunctions.length);
        for (uint256 i; i < _allowedFunctions.length; i++) {
            allowedFunctions[i] = bytes4(_allowedFunctions[i]);
        }
        config = ConfigParams({
            flags: $subHook().permissions[account][module].flags,
            allowedTargets: allowedTargets,
            allowedFunctions: allowedFunctions
        });
    }

    function configure(address module, ConfigParams memory params) public {
        ModulePermissions storage $modulePermissions = $subHook().permissions[msg.sender][module];
        $modulePermissions.flags = params.flags;

        uint256 length = params.allowedTargets.length;
        $modulePermissions.allowedTargets.init();
        for (uint256 i; i < length; i++) {
            $modulePermissions.allowedTargets.push(params.allowedTargets[i]);
        }
        length = params.allowedFunctions.length;
        for (uint256 i; i < length; i++) {
            $modulePermissions.allowedFunctions.push(bytes32(params.allowedFunctions[i]));
        }
    }

    function _getSSTORE2Ref(address module, address attester) internal pure returns (address) {
        // TODO: implement actual registry lookup
        return address(0xbBb6987cD1807141DBc07A9C164CAB37603Db429);
    }

    function configureWithRegistry(address module, address attester) external {
        ConfigParams memory params =
            abi.decode(SSTORE2.read(_getSSTORE2Ref(module, attester)), (ConfigParams));
        configure(module, params);
    }

    function onExecute(
        address smartAccount,
        address superVisorModule,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        virtual
        onlyMultiplexer
        returns (bytes memory hookData)
    {
        console2.log("onExecute subhook");
        ModulePermissions storage $modulePermissions =
            $subHook().permissions[smartAccount][superVisorModule];

        PermissionFlags flags = $modulePermissions.flags;

        bytes4 functionSig = callData.length > 4 ? bytes4(callData[0:4]) : bytes4(0);

        // check for self call
        if (!flags.isSelfCall() && target == smartAccount) {
            revert InvalidPermission();
        }

        // check for module Call
        // TODO:
        // if (!flags.moduleCall) {
        //     // if (!flags.moduleCall && IERC7579Module(target).moduleId(msg.sender)) {
        //     revert InvalidPermission();
        // }

        // check for value transfer
        if (!flags.isSendValue() && value > 0) {
            revert InvalidPermission();
        }

        // Calldata permissions
        if (flags.isERC20Transfer() && functionSig.isERC20Transfer()) {
            revert InvalidPermission();
        }

        if (flags.isERC721Transfer() && functionSig.isERC721Transfer()) {
            revert InvalidPermission();
        }

        // check if target address is allowed to be called
        if (flags.hasAllowedTargets() && !$modulePermissions.allowedTargets.contains(target)) {
            revert InvalidPermission();
        }

        // check if target functioni is allowed to be called
        if (
            flags.hasAllowedFunctions()
                && !$modulePermissions.allowedFunctions.contains(bytes32(functionSig))
        ) {
            revert InvalidPermission();
        }
    }

    function onExecuteBatch(
        address smartAccount,
        address superVisorModule,
        Execution[] calldata
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onExecuteFromExecutor(
        address smartAccount,
        address superVisorModule,
        address target,
        uint256 value,
        bytes calldata callData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onExecuteBatchFromExecutor(
        address smartAccount,
        address superVisorModule,
        Execution[] calldata
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onInstallModule(
        address smartAccount,
        address superVisorModule,
        uint256 moduleType,
        address module,
        bytes calldata initData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onUninstallModule(
        address smartAccount,
        address superVisorModule,
        uint256 moduleType,
        address module,
        bytes calldata deInitData
    )
        external
        virtual
        override
        returns (bytes memory hookData)
    { }

    function onPostCheck(bytes calldata hookData) external virtual returns (bool success) { }
}
