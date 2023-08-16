// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UserOperation} from "@aa/interfaces/UserOperation.sol";

// interface for modules to verify singatures signed over userOpHash
interface IValidatorModule {
    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash)
        external
        returns (uint256 validationData);
}
