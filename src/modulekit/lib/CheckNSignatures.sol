// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ECDSA } from "solady/utils/ECDSA.sol";
import "../../common/IERC1271.sol";

error InvalidSignature();

error WrongContractSignatureFormat(uint256 s, uint256 contractSignatureLen, uint256 signaturesLen);
error WrongContractSignature(bytes contractSignature);
error WrongSignature(bytes signature);

library CheckSignatures {
    function recoverNSignatures(
        bytes32 dataHash,
        bytes memory signatures,
        uint256 requiredSignatures
    )
        internal
        view
        returns (address[] memory recoveredSigners)
    {
        uint256 requiredSignatureLength = requiredSignatures * 65;
        uint256 signaturesLength = signatures.length;
        recoveredSigners = new address[](requiredSignatures);
        if (signaturesLength < requiredSignatureLength) revert InvalidSignature();

        for (uint256 i; i < requiredSignatures; i++) {
            // split v,r,s from signatures
            address _signer;
            (uint8 v, bytes32 r, bytes32 s) = signatureSplit({ signatures: signatures, pos: i });

            if (v == 0) {
                // If v is 0 then it is a contract signature
                // When handling contract signatures the address of the signer contract is encoded into r
                _signer = address(uint160(uint256(r)));

                // Check that signature data pointer (s) is not pointing inside the static part of the signatures bytes
                // Here we check that the pointer is not pointing inside the part that is being processed
                if (uint256(s) < 65) {
                    revert WrongContractSignatureFormat(uint256(s), 0, 0);
                }

                if (uint256(s) + 32 > signaturesLength) {
                    revert WrongContractSignatureFormat(uint256(s), 0, signaturesLength);
                }

                // Check if the contract signature is in bounds: start of data is s + 32 and end is start + signature length
                uint256 contractSignatureLen;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    contractSignatureLen := mload(add(add(signatures, s), 0x20))
                }
                if (uint256(s) + 32 + contractSignatureLen > signaturesLength) {
                    revert WrongContractSignatureFormat(
                        uint256(s), contractSignatureLen, signaturesLength
                    );
                }

                // Check signature
                bytes memory contractSignature;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    // The signature data for contract signatures is appended to the concatenated signatures and the offset is stored in s
                    contractSignature := add(add(signatures, s), 0x20)
                }
                if (
                    IERC1271(_signer).isValidSignature(dataHash, contractSignature)
                        != ERC1271_MAGICVALUE
                ) revert WrongContractSignature(contractSignature);
            } else if (v > 30) {
                // If v > 30 then default va (27,28) has been adjusted for eth_sign flow
                // To support eth_sign and similar we adjust v and hash the messageHash with the Ethereum message prefix before applying ecrecover
                _signer = ECDSA.tryRecover({
                    hash: ECDSA.toEthSignedMessageHash(dataHash),
                    v: v - 4,
                    r: r,
                    s: s
                });
            } else {
                _signer = ECDSA.tryRecover({ hash: dataHash, v: v, r: r, s: s });
            }
            recoveredSigners[i] = _signer;
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
    function signatureSplit(
        bytes memory signatures,
        uint256 pos
    )
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        // solhint-disable-next-line no-inline-assembly
        /// @solidity memory-safe-assembly
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            v := byte(0, mload(add(signatures, add(signaturePos, 0x60))))
        }
    }
}
