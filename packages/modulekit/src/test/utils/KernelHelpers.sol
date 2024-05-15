pragma solidity ^0.8.23;

import {ValidatorLib} from "kernel/utils/ValidationTypeLib.sol";
import {ValidationType, ValidationMode} from "kernel/types/Types.sol";
import {VALIDATION_TYPE_ROOT, VALIDATION_TYPE_VALIDATOR, VALIDATION_MODE_DEFAULT, VALIDATION_MODE_ENABLE, VALIDATION_TYPE_PERMISSION} from "kernel/types/Constants.sol";
import {ENTRYPOINT_ADDR} from "../predeploy/EntryPoint.sol";
import {IEntryPoint} from "kernel/interfaces/IEntryPoint.sol";

library KernelHelpers {
    function encodeNonce(
        ValidationType vType,
        bool enable,
        address account,
        address validator
    ) internal view returns (uint256 nonce) {
        uint192 nonceKey = 0;
        if (vType == VALIDATION_TYPE_ROOT) {
            nonceKey = 0;
        } else if (vType == VALIDATION_TYPE_VALIDATOR) {
            ValidationMode mode = VALIDATION_MODE_DEFAULT;
            if (enable) {
                mode = VALIDATION_MODE_ENABLE;
            }
            nonceKey = ValidatorLib.encodeAsNonceKey(
                ValidationMode.unwrap(mode),
                ValidationType.unwrap(vType),
                bytes20(validator),
                0 // parallel key
            );
        } else {
            revert("Invalid validation type");
        }
        return IEntryPoint(ENTRYPOINT_ADDR).getNonce(account, nonceKey);
    }
}
