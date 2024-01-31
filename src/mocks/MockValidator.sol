// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable no-unused-vars */
import { ERC7579ValidatorBase } from "../Modules.sol";
import { UserOperation } from "../external/ERC4337.sol";
import { ModuleTypeLib, EncodedModuleTypes, ModuleType } from "umsa/lib/ModuleTypeLib.sol";

contract MockValidator is ERC7579ValidatorBase {
    EncodedModuleTypes immutable MODULE_TYPES;

    constructor() {
        ModuleType[] memory moduleTypes = new ModuleType[](1);
        moduleTypes[0] = ModuleType.wrap(TYPE_VALIDATOR);
        MODULE_TYPES = ModuleTypeLib.bitEncode(moduleTypes);
    }

    function onInstall(bytes calldata data) external virtual override { }

    function onUninstall(bytes calldata data) external virtual override { }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        return
            _packValidationData({ sigFailed: false, validUntil: type(uint48).max, validAfter: 0 });
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        return EIP1271_SUCCESS;
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function getModuleTypes() external view returns (EncodedModuleTypes) {
        return MODULE_TYPES;
    }

    function isInitialized(address smartAccount) external pure returns (bool) {
        return false;
    }
}
