// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { AutoSavingToVault } from "../src/AutoSavings/AutoSavings.sol";
import { AutoSendSessionKey } from "../src/AutoSend/AutoSend.sol";
import { FlashloanCallback } from "../src/ColdStorage/FlashloanCallback.sol";
import { FlashloanLender } from "../src/ColdStorage/FlashloanLender.sol";
import { ColdStorageHook } from "../src/ColdStorage/ColdStorageHook.sol";
import { ColdStorageExecutor } from "../src/ColdStorage/ColdStorageExecutor.sol";
import { DeadmanSwitch } from "../src/DeadmanSwitch/DeadmanSwitch.sol";
import { DollarCostAverage } from "../src/DollarCostAverage/DollarCostAverage.sol";
import { MultiFactor } from "../src/MultiFactor/MultiFactor.sol";
import { OwnableValidator } from "../src/OwnableValidator/OwnableValidator.sol";
import { ScheduledOrders } from "../src/ScheduledTransactions/ScheduledOrders.sol";
import { ScheduledTransfers } from "../src/ScheduledTransactions/ScheduledTransfers.sol";
import { WebAuthnValidator } from "../src/WebAuthnValidator/WebAuthnValidator.sol";

/**
 * @title Deploy
 * @author @kopy-kat
 */
contract DeployScript is Script {
    function run() public {
        bytes32 salt = bytes32(uint256(0));

        vm.startBroadcast(vm.envUint("PK"));

        // Deploy Modules
        AutoSavingToVault autoSavings = new AutoSavingToVault{ salt: salt }();

        AutoSendSessionKey autoSend = new AutoSendSessionKey{ salt: salt }();

        FlashloanCallback flashloanCallback = new FlashloanCallback{ salt: salt }();
        FlashloanLender flashloanLender = new FlashloanLender{ salt: salt }();
        ColdStorageHook coldStorageHook = new ColdStorageHook{ salt: salt }();
        ColdStorageExecutor coldStorageExecutor = new ColdStorageExecutor{ salt: salt }();

        DeadmanSwitch deadmanSwitch = new DeadmanSwitch{ salt: salt }();

        DollarCostAverage dollarCostAverage = new DollarCostAverage{ salt: salt }();

        MultiFactor multiFactor = new MultiFactor{ salt: salt }();

        OwnableValidator ownableValidator = new OwnableValidator{ salt: salt }();

        ScheduledOrders scheduledOrders = new ScheduledOrders{ salt: salt }();
        ScheduledTransfers scheduledTransfers = new ScheduledTransfers{ salt: salt }();

        WebAuthnValidator webAuthnValidator = new WebAuthnValidator{ salt: salt }();

        vm.stopBroadcast();
    }
}
