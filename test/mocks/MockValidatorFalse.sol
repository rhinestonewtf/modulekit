// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

/* solhint-disable no-unused-vars */
import { ERC7579StatelessValidatorBase } from "src/Modules.sol";
import { ERC7579ValidatorBase } from "src/Modules.sol";
import { PackedUserOperation } from "src/external/ERC4337.sol";

contract MockValidatorFalse is ERC7579StatelessValidatorBase, ERC7579ValidatorBase {
    function onInstall(bytes calldata data) external virtual override { }

    function onUninstall(bytes calldata data) external virtual override { }

    function validateUserOp(
        PackedUserOperation calldata, // userOp
        bytes32 // userOpHash
    )
        external
        virtual
        override
        returns (ValidationData)
    {
        return _packValidationData({ sigFailed: true, validUntil: type(uint48).max, validAfter: 0 });
    }

    function isValidSignatureWithSender(
        address, // sender
        bytes32, // hash
        bytes calldata // signature
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        return EIP1271_FAILED;
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function isInitialized(
        address // smartAccount
    )
        external
        pure
        returns (bool)
    {
        return false;
    }

    function validateSignatureWithData(
        bytes32,
        bytes calldata,
        bytes calldata
    )
        external
        pure
        override
        returns (bool validSig)
    {
        return false;
    }
}
