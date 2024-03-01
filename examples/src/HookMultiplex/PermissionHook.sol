// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookDestruct } from "@rhinestone/modulekit/src/modules/ERC7579HookDestruct.sol";
import { SENTINEL as SENTINELAddress, SentinelListLib } from "sentinellist/SentinelList.sol";
import { SENTINEL as SENTINELBytes32, LinkedBytes32Lib } from "sentinellist/SentinelListBytes32.sol";
import { TokenTransactionLib } from "./lib/TokenTransactionLib.sol";
import { PermissionFlag, PermissionFlagLib } from "./lib/PermissionFlagLib.sol";
import { SSTORE2 } from "solady/src/utils/SSTORE2.sol";

contract PermissionHook is ERC7579HookDestruct {
    using SentinelListLib for SentinelListLib.SentinelList;
    using LinkedBytes32Lib for LinkedBytes32Lib.LinkedBytes32;
    using TokenTransactionLib for bytes4;
    using PermissionFlagLib for PermissionFlag;

    error InvalidPermission();

    struct ConfigParams {
        PermissionFlag flags;
        address[] allowedTargets;
        bytes4[] allowedFunctions;
    }

    struct ModulePermissions {
        PermissionFlag flags;
        LinkedBytes32Lib.LinkedBytes32 allowedFunctions;
        SentinelListLib.SentinelList allowedTargets;
    }

    mapping(address account => mapping(address module => ModulePermissions)) internal $permissions;
    mapping(address account => mapping(address module => SentinelListLib.SentinelList subHooks))
        internal $moduleSubHooks;

    mapping(address smartAccount => LinkedBytes32Lib.LinkedBytes32 globalSubHooks) internal
        $globalSubHooks;

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

    function configureWithRegistry(address module, address attester) external {
        ConfigParams memory params =
            abi.decode(SSTORE2.read(_getSSTORE2Ref(module, attester)), (ConfigParams));
        configure(module, params);
    }

    function _getSSTORE2Ref(address module, address attester) internal pure returns (address) {
        // TODO: implement actual registry lookup
        return address(0xbBb6987cD1807141DBc07A9C164CAB37603Db429);
    }
}
