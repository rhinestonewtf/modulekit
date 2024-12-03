// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0 <0.9.0;

// Interfaces
import { IERC165 } from "forge-std/interfaces/IERC165.sol";

// Types
import { AttestationRecord } from "../types/DataTypes.sol";

/**
 * @title The interface of an optional schema resolver.
 */
interface IExternalSchemaValidator is IERC165 {
    /**
     * @notice Validates an attestation request.
     */
    function validateSchema(AttestationRecord calldata attestation) external returns (bool);

    /**
     * @notice Validates an array of attestation requests.
     */
    function validateSchema(AttestationRecord[] calldata attestations) external returns (bool);
}
