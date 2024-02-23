/* solhint-disable */
//********************************************************************************************/
//  ___           _       ___               _         _    _ _
// | __| _ ___ __| |_    / __|_ _ _  _ _ __| |_ ___  | |  (_) |__
// | _| '_/ -_|_-< ' \  | (__| '_| || | '_ \  _/ _ \ | |__| | '_ \
// |_||_| \___/__/_||_|  \___|_|  \_, | .__/\__\___/ |____|_|_.__/
//                                |__/|_|
///* Copyright (C) 2022 - Renaud Dubois - This file is part of FCL (Fresh CryptoLib) project
///* License: This software is licensed under MIT License
///* This Code may be reused including license and copyright notice.
///* See LICENSE file at the root folder of the project.
///* FILE: FCL_elliptic.sol
///*
///*
///* DESCRIPTION: Implementation of the WebAuthn Authentication mechanism
///* https://www.w3.org/TR/webauthn-2/#sctn-intro
///* Original code extracted from https://github.com/btchip/Webauthn.sol
//**************************************************************************************/
//* WARNING: this code SHALL not be used for non prime order curves for security reasons.
// Code is optimized for a=-3 only curves with prime order, constant like -1, -2 shall be replaced
// if ever used for other curve than sec256R1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Base64URL } from "./Base64URL.sol";
import { EllipticCurveP256 } from "./EllipticCurve.sol";

library WebAuthnLib {
    error InvalidAuthenticatorData();
    error InvalidClientData();
    error InvalidSignature();

    function WebAuthn_format(
        bytes memory authenticatorData,
        bytes1 authenticatorDataFlagMask,
        bytes memory clientData,
        bytes32 clientChallenge,
        uint256 clientChallengeDataOffset,
        uint256[2] memory rs
    )
        internal
        view
        returns (bytes32 result)
    {
        // Let the caller check if User Presence (0x01) or User Verification (0x04) are set
        {
            if ((authenticatorData[32] & authenticatorDataFlagMask) != authenticatorDataFlagMask) {
                revert InvalidAuthenticatorData();
            }
            // Verify that clientData commits to the expected client challenge
            string memory challengeEncoded = Base64URL.encode32(abi.encodePacked(clientChallenge));

            // previous implementation that used bytes calldata clientData
            // bytes memory challengeExtracted = new bytes(
            //     bytes(challengeEncoded).length
            // );

            // // Extract challenge from clientData
            // assembly {
            //     calldatacopy(
            //         add(challengeExtracted, 32),
            //         add(clientData.offset, clientChallengeDataOffset),
            //         mload(challengeExtracted)
            //     )
            // }

            // bytes32 more; //=keccak256(abi.encodePacked(challengeExtracted));
            // assembly {
            //     more := keccak256(
            //         add(challengeExtracted, 32),
            //         mload(challengeExtracted)
            //     )
            // }

            // TODO: extract challenge from clientData and compare to clientChallenge
            bytes32 more = keccak256(abi.encodePacked(challengeEncoded));

            if (keccak256(abi.encodePacked(bytes(challengeEncoded))) != more) {
                revert InvalidClientData();
            }
        } //avoid stack full

        // Verify the signature over sha256(authenticatorData || sha256(clientData))
        // bytes memory verifyData = new bytes(authenticatorData.length + 32);

        // // get authenticatorData
        // assembly {
        //     mstore(add(verifyData, 32), authenticatorData)
        // }

        bytes32 more = sha256(clientData);
        // uint _authenticatorLength = authenticatorData.length;
        // assembly {
        //     mstore(add(verifyData, add(_authenticatorLength, 32)), more)
        // }

        bytes memory verifyData = abi.encodePacked(authenticatorData, more);

        return sha256(verifyData);
    }

    function checkSignature(
        bytes memory authenticatorData,
        bytes1 authenticatorDataFlagMask,
        bytes memory clientData,
        bytes32 clientChallenge,
        uint256 clientChallengeDataOffset,
        uint256[2] memory rs,
        uint256[2] memory Q
    )
        internal
        returns (bool)
    {
        // Let the caller check if User Presence (0x01) or User Verification (0x04) are set

        bytes32 message = WebAuthnLib.WebAuthn_format(
            authenticatorData,
            authenticatorDataFlagMask,
            clientData,
            clientChallenge,
            clientChallengeDataOffset,
            rs
        );

        bool result = EllipticCurveP256.ecdsa_verify_mem(message, rs, Q);

        return result;
    }

    function checkSignature_prec(
        bytes calldata authenticatorData,
        bytes1 authenticatorDataFlagMask,
        bytes calldata clientData,
        bytes32 clientChallenge,
        uint256 clientChallengeDataOffset,
        uint256[2] calldata rs,
        address dataPointer
    )
        internal
        returns (bool)
    {
        // Let the caller check if User Presence (0x01) or User Verification (0x04) are set

        bytes32 message = WebAuthnLib.WebAuthn_format(
            authenticatorData,
            authenticatorDataFlagMask,
            clientData,
            clientChallenge,
            clientChallengeDataOffset,
            rs
        );

        bool result = EllipticCurveP256.ecdsa_precomputed_verify(message, rs, dataPointer);

        return result;
    }

    //beware that this implementation will not be compliant with EOF
    function checkSignature_hackmem(
        bytes calldata authenticatorData,
        bytes1 authenticatorDataFlagMask,
        bytes calldata clientData,
        bytes32 clientChallenge,
        uint256 clientChallengeDataOffset,
        uint256[2] calldata rs,
        uint256 dataPointer
    )
        internal
        returns (bool)
    {
        // Let the caller check if User Presence (0x01) or User Verification (0x04) are set

        bytes32 message = WebAuthnLib.WebAuthn_format(
            authenticatorData,
            authenticatorDataFlagMask,
            clientData,
            clientChallenge,
            clientChallengeDataOffset,
            rs
        );

        bool result = EllipticCurveP256.ecdsa_precomputed_hackmem(message, rs, dataPointer);

        return result;
    }
}
/* solhint-enable */
