// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import {
    IValidator,
    VALIDATION_SUCCESS,
    VALIDATION_FAILED,
    MODULE_TYPE_VALIDATOR
} from "src/accounts/common/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "src/external/ERC4337.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { EIP1271_MAGIC_VALUE, IERC1271 } from "src/module-bases/interfaces/IERC1271.sol";

contract MockK1ValidatorUncompliantUninstall is IValidator {
    bytes4 constant ERC1271_INVALID = 0xffffffff;
    mapping(address => address) public smartAccountOwners;

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        payable
        returns (uint256 validation)
    {
        return ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(userOpHash), userOp.signature)
            == smartAccountOwners[msg.sender] ? VALIDATION_SUCCESS : VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(
        address,
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        returns (bytes4)
    {
        return ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(hash), signature)
            == smartAccountOwners[msg.sender] ? EIP1271_MAGIC_VALUE : ERC1271_INVALID;
    }

    function onInstall(bytes calldata data) external {
        address owner = abi.decode(data, (address));
        smartAccountOwners[msg.sender] = owner;
    }

    function onUninstall(bytes calldata data) external pure {
        data;
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    function isOwner(address account, address owner) external view returns (bool) {
        return smartAccountOwners[account] == owner;
    }

    function isInitialized(address) external pure returns (bool) {
        return false;
    }

    function getOwner(address account) external view returns (address) {
        return smartAccountOwners[account];
    }
}
