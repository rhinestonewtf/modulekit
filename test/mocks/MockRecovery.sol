// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRecoveryModule} from "../../src/modules/recovery/IRecoveryModule.sol";

/// @title MockRecovery
/// @author kopy-kat

contract MockRecovery is IRecoveryModule {
    // <---- IRECOVERY FUNCTIONS ---->
    function validateRecoveryProof(bytes calldata recoveryProof) external override returns (bool) {
        return false;
    }

    function getRecoverySchema() external view returns (string memory) {
        return "";
    }
}
