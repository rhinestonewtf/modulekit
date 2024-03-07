// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { SessionKeyManager } from "../src/SessionKeyManager.sol";

/**
 * @title Deploy
 * @author @kopy-kat
 */
contract DeployScript is Script {
    function run() public {
        bytes32 salt = bytes32(uint256(0));

        vm.startBroadcast(vm.envUint("PK"));

        // Deploy Session Key Manager
        SessionKeyManager sessionKeyManager = new SessionKeyManager{ salt: salt }();

        vm.stopBroadcast();
    }
}
