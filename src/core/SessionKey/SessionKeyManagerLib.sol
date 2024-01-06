// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ISessionValidationModule } from "./ISessionValidationModule.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";

struct SessionData {
    uint48 validUntil;
    uint48 validAfter;
    ISessionValidationModule sessionValidationModule;
    bytes sessionKeyData;
}

library SessionKeyManagerLib {
    uint8 internal constant NULL = 0x00;

    function digest(SessionData calldata _data) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                _data.validUntil,
                _data.validAfter,
                _data.sessionValidationModule,
                _data.sessionKeyData
            )
        );
    }

    function recoverSessionKeySigner(
        bytes32 userOpHash,
        bytes calldata signature
    )
        internal
        view
        returns (address)
    {
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), signature);
    }

    function recoverSessionKeySignerM(
        bytes32 userOpHash,
        bytes memory signature
    )
        internal
        view
        returns (address)
    {
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), signature);
    }

    function encodeSignature(
        bytes32 digest,
        bytes memory sessionKeySignature
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(NULL, abi.encode(digest, sessionKeySignature));
    }

    function encodeSignature(
        bytes32[] memory digests,
        bytes[] memory sessionKeySignatures
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(NULL, abi.encode(digests, sessionKeySignatures));
    }

    function decodeSignatureSingle(bytes calldata signature)
        internal
        pure
        returns (bytes32 digest, bytes calldata sessionKeySignature)
    {
        /*
        * Session Data Pre Enabled Signature Layout
        * Offset (in bytes)    | Length (in bytes) | Contents
        * 0x0                  | 0x1               | Is Session Enable Transaction Flag
        * 0x1                  | --                | abi.encode(bytes32 sessionDataDigest,
        sessionKeySignature)
         */
        assembly ("memory-safe") {
            let offset := add(signature.offset, 0x1)
            let baseOffset := offset

            digest := calldataload(offset)
            offset := add(offset, 0x20)

            let dataPointer := add(baseOffset, calldataload(offset))
            sessionKeySignature.offset := add(dataPointer, 0x20)
            sessionKeySignature.length := calldataload(dataPointer)
        }
    }

    function decodeSignatureBatch(bytes calldata signature)
        internal
        pure
        returns (bytes32[] calldata sessionKeyDigests, bytes[] calldata sessionKeySignatures)
    {
        {
            /*
             * Module Signature Layout
             */
            assembly ("memory-safe") {
                let offset := add(signature.offset, 0x1)
                let baseOffset := offset

                let dataPointer := add(baseOffset, calldataload(offset))
                sessionKeyDigests.offset := add(dataPointer, 0x20)
                sessionKeyDigests.length := calldataload(dataPointer)
                offset := add(offset, 0x20)

                dataPointer := add(baseOffset, calldataload(offset))
                sessionKeySignatures.offset := add(dataPointer, 0x20)
                sessionKeySignatures.length := calldataload(dataPointer)
                offset := add(offset, 0x20)
            }
        }
    }
}
