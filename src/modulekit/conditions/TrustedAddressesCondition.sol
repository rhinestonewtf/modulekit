// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ICondition } from "../interfaces/IExecutor.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract TrustedAddressesCondition is ICondition, Ownable {
    bytes32 trustedAddressesRoot;

    struct Params {
        bytes32[] proof;
        address checkAddress;
    }

    error InvalidProof();
    error InvalidAddress();

    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    function setTrustedAddressesRoot(bytes32 _trustedAddressesRoot) external onlyOwner {
        trustedAddressesRoot = _trustedAddressesRoot;
    }

    function leaf(address checkAddress) public pure returns (bytes32) {
        if (checkAddress == address(0)) revert InvalidAddress();
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
        if (root == bytes32(0)) revert InvalidProof();

        return MerkleProofLib.verify(params.proof, root, leaf(params.checkAddress));
    }
}
