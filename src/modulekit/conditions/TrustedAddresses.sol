// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICondition } from "../interfaces/IExecutor.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";

contract MerkleTreeCondition is ICondition {
    bytes32 trustedAddressesRoot;

    struct Params {
        bytes32[] proof;
        address checkAddress;
    }

    function setTrustedAddressesRoot(bytes32 _trustedAddressesRoot) external {
        trustedAddressesRoot = _trustedAddressesRoot;
    }

    function leaf(address checkAddress) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(checkAddress));
    }

    function checkCondition(
        address,
        address,
        bytes calldata conditionData,
        bytes calldata
    )
        external
        view
        override
        returns (bool)
    {
        Params memory params = abi.decode(conditionData, (Params));

        bytes32 root = trustedAddressesRoot;
        if (root == bytes32(0)) revert();

        return MerkleProofLib.verify(params.proof, root, leaf(params.checkAddress));
    }
}
