// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "../Modules.sol";
import { UserOperation } from "../external/ERC4337.sol";

contract MockValidator is ERC7579ValidatorBase {
    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata data) external override { }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        return _packValidationData({ sigFailed: false, validUntil: 1000, validAfter: 0 });
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

    function name() external pure virtual override returns (string memory) {
        return "MockValidator";
    }

    function version() external pure virtual override returns (string memory) {
        return "0.0.1";
    }
}
