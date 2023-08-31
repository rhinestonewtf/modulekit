// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISignatureValidator} from "../../validators/ISignatureValidator.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";

bytes4 constant EIP1271_MAGIC_VALUE = 0x20c13b0b;

error InvalidSignature();

function _checkNSignatures(bytes32 dataHash, bytes memory data, bytes memory signatures, uint256 requiredSignatures)
    view
{
    uint256 requiredSignatureLength = requiredSignatures * 65;
    uint256 signatureLength = signatures.length;
    if (signatureLength < requiredSignatureLength) revert InvalidSignature();

    address lastGuardian = address(0);
    address currentGuardian;

    for (uint256 i; i < requiredSignatures; i++) {
        // split v,r,s from signatures
        (uint8 v, bytes32 r, bytes32 s) = signatureSplit({signatures: signatures, pos: i});

        address signer = address(uint160(uint256(r)));

        // Check that signature data pointer (s) is not pointing inside the static part of the signatures bytes
        // This check is not completely accurate, since it is possible that more signatures than the threshold are send.
        // Here we only check that the pointer is not pointing inside the part that is being processed
        if (uint256(s) < requiredSignatureLength) revert InvalidSignature();

        // Check that signature data pointer (s) is in bounds (points to the length of data -> 32 bytes)
        if ((uint256(s) + 32) > signatureLength) revert InvalidSignature();

        // Check if the contract signature is in bounds: start of data is s + 32 and end is start + signature length
        uint256 contractSignatureLen;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            contractSignatureLen := mload(add(add(signatures, s), 0x20))
        }
        if ((uint256(s) + 32 + contractSignatureLen) > signatureLength) revert InvalidSignature();

        // Check signature
        bytes memory signature;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // The signature data for contract signatures is appended to the concatenated signatures and the offset is stored in s
            signature := add(add(signatures, s), 0x20)
        }

        SignatureCheckerLib.isValidSignatureNow(signer, dataHash, signature);
    }
}

/**
 * @notice Splits signature bytes into `uint8 v, bytes32 r, bytes32 s`.
 * @dev Make sure to perform a bounds check for @param pos, to avoid out of bounds access on @param signatures
 *      The signature format is a compact form of {bytes32 r}{bytes32 s}{uint8 v}
 *      Compact means uint8 is not padded to 32 bytes.
 * @param pos Which signature to read.
 *            A prior bounds check of this parameter should be performed, to avoid out of bounds access.
 * @param signatures Concatenated {r, s, v} signatures.
 * @return v Recovery ID or Safe signature type.
 * @return r Output value r of the signature.
 * @return s Output value s of the signature.
 *
 * @ author Gnosis Team /rmeissner
 */
function signatureSplit(bytes memory signatures, uint256 pos) pure returns (uint8 v, bytes32 r, bytes32 s) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
        let signaturePos := mul(0x41, pos)
        r := mload(add(signatures, add(signaturePos, 0x20)))
        s := mload(add(signatures, add(signaturePos, 0x40)))
        /**
         * Here we are loading the last 32 bytes, including 31 bytes
         * of 's'. There is no 'mload8' to do this.
         * 'byte' is not working due to the Solidity parser, so lets
         * use the second best option, 'and'
         */
        v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
    }
}
