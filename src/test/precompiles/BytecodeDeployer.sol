// // SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract BytecodeDeployer {
    /// @notice Deploys a contract using CREATE, reverts on failure
    function _deploy(bytes memory creationBytecode) internal returns (address contractAddress) {
        assembly {
            contractAddress := create(0, add(creationBytecode, 0x20), mload(creationBytecode))
        }
        require(contractAddress != address(0), "Deployer: deployment failed");
    }
}
