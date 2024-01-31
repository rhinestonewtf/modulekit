// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable no-unused-vars */
import { ERC7579ValidatorBase } from "../Modules.sol";
import { UserOperation } from "../external/ERC4337.sol";

contract MockValidator is ERC7579ValidatorBase {
    function onInstall(bytes calldata data) external virtual override { }

    function onUninstall(bytes calldata data) external virtual override { }

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

    function moduleId() external pure virtual override returns (string memory) {
        return "MockHook.v0.0.1";
    }

    function isInitialized(address smartAccount) external pure returns (bool) {
        return false;
    }
}
