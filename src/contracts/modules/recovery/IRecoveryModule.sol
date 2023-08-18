// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

interface IRecoveryModule {
    function validateRecoveryProof(bytes calldata recoveryProof) external returns (bool);

    // used to abi decode the recovery proof
    function getRecoverySchema() external view returns (string memory);
}
