// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { Validator, validatorId } from "./DataTypes.sol";
import "forge-std/console2.sol";

library MultiFactorLib {
    function decode(bytes calldata data) internal pure returns (Validator[] calldata validators) {
        // (Validator[]) = abi.decode(data,(Validator[])
        assembly ("memory-safe") {
            let offset := data.offset
            let baseOffset := offset
            let dataPointer := add(baseOffset, calldataload(offset))

            validators.offset := add(dataPointer, 32)
            validators.length := calldataload(dataPointer)
            offset := add(offset, 32)

            dataPointer := add(baseOffset, calldataload(offset))
        }
    }

    function pack(address subValidator, validatorId id) internal pure returns (bytes32 _packed) {
        _packed = bytes32(abi.encodePacked(validatorId.unwrap(id), subValidator));
    }

    function unpack(bytes32 packed) internal pure returns (address subValidator, validatorId id) {
        assembly {
            subValidator := packed
            id := shl(0, packed)
        }
    }
}
