// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { IERC7484 } from "modulekit/src/interfaces/IERC7484.sol";

import { AutoSavings } from "src/AutoSavings/AutoSavings.sol";
import { ColdStorageHook } from "src/ColdStorageHook/ColdStorageHook.sol";
import { ColdStorageFlashloan } from "src/ColdStorageHook/ColdStorageFlashloan.sol";
import { DeadmanSwitch } from "src/DeadmanSwitch/DeadmanSwitch.sol";
import { HookMultiPlexer } from "src/HookMultiPlexer/HookMultiPlexer.sol";
import { MultiFactor } from "src/MultiFactor/MultiFactor.sol";
import { OwnableExecutor } from "src/OwnableExecutor/OwnableExecutor.sol";
import { OwnableValidator } from "src/OwnableValidator/OwnableValidator.sol";
import { RegistryHook } from "src/RegistryHook/RegistryHook.sol";
import { ScheduledOrders } from "src/ScheduledOrders/ScheduledOrders.sol";
import { ScheduledTransfers } from "src/ScheduledTransfers/ScheduledTransfers.sol";
import { SocialRecovery } from "src/SocialRecovery/SocialRecovery.sol";

/**
 * @title Deploy
 * @author @kopy-kat
 */
contract DeployScript is Script {
    function run() public {
        bytes32 salt = bytes32(uint256(0));
        IERC7484 registry = IERC7484(0x1D8c40F958Fb6998067e9B8B26850d2ae30b7c70); // mock registry

        vm.startBroadcast(vm.envUint("PK"));

        // Deploy Modules
        new AutoSavings{ salt: salt }();
        new ColdStorageHook{ salt: salt }();
        new ColdStorageFlashloan{ salt: salt }();
        new DeadmanSwitch{ salt: salt }();
        new HookMultiPlexer{ salt: salt }(registry);
        new MultiFactor{ salt: salt }(registry);
        new OwnableExecutor{ salt: salt }();
        new OwnableValidator{ salt: salt }();
        new RegistryHook{ salt: salt }();
        new ScheduledOrders{ salt: salt }();
        new ScheduledTransfers{ salt: salt }();
        new SocialRecovery{ salt: salt }();

        vm.stopBroadcast();
    }
}
