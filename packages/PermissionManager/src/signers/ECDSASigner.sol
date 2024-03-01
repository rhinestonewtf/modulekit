pragma solidity ^0.8.0;

import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/modules/ERC7579ValidatorBase.sol";
import { ISigner } from "../ISigner.sol";

import "forge-std/console2.sol";

contract ECDSASigner is ISigner {
    using ECDSA for bytes32;

    mapping(
        address caller => mapping(bytes32 permissionId => mapping(address smartAccount => address))
    ) public signer;

    function registerSigner(
        address smartAccount,
        bytes32 permissionId,
        bytes calldata data
    )
        external
        payable
        override
    {
        console2.logBytes(data);
        require(
            signer[msg.sender][permissionId][smartAccount] == address(0),
            "ECDSASigner: smartAccount already registered"
        );
        require(data.length == 20, "ECDSASigner: invalid signer address");
        address signerAddress = address(bytes20(data[0:20]));
        signer[msg.sender][permissionId][smartAccount] = signerAddress;
    }

    function validateUserOp(
        address smartAccount,
        bytes32 permissionId,
        bytes32 userOpHash,
        bytes calldata signature
    )
        external
        payable
        override
        returns (ERC7579ValidatorBase.ValidationData)
    {
        require(
            signer[msg.sender][permissionId][smartAccount] != address(0),
            "ECDSASigner: smartAccount not registered"
        );
        address recovered = ECDSA.toEthSignedMessageHash(userOpHash).recover(signature);
        if (recovered == signer[msg.sender][permissionId][smartAccount]) {
            return ERC7579ValidatorBase.ValidationData.wrap(0);
        }
        return ERC7579ValidatorBase.ValidationData.wrap(1);
    }

    function validateSignature(
        address smartAccount,
        bytes32 permissionId,
        bytes32 messageHash,
        bytes calldata signature
    )
        external
        view
        override
        returns (ERC7579ValidatorBase.ValidationData)
    {
        address signerAddress = signer[msg.sender][permissionId][smartAccount];
        require(signerAddress != address(0), "ECDSASigner: smartAccount not registered");
        if (messageHash.recover(signature) == signerAddress) {
            return ERC7579ValidatorBase.ValidationData.wrap(0);
        }
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        address recovered = ethHash.recover(signature);
        if (recovered == signerAddress) {
            return ERC7579ValidatorBase.ValidationData.wrap(0);
        }
        return ERC7579ValidatorBase.ValidationData.wrap(1);
    }
}
