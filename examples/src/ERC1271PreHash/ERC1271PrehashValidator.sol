// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { ERC7579ValidatorBase } from "modulekit/src/modules/ERC7579ValidatorBase.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";

contract ERC1271PrehashValidator is ERC7579ValidatorBase {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address account => EnumerableSet.Bytes32Set) internal _validHashes;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        if (data.length == 0) return;

        bytes32[] memory hashes = abi.decode(data, (bytes32[]));
        for (uint256 i; i < hashes.length; i++) {
            _validHashes[msg.sender].add(hashes[i]);
        }
    }

    function onUninstall(bytes calldata data) external override {
        // Todo
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        // Todo
    }

    function addHash(bytes32 _hash) external {
        _validHashes[msg.sender].add(_hash);
    }

    function removeHash(bytes32 _hash) external {
        _validHashes[msg.sender].remove(_hash);
    }

    function isHash(address account, bytes32 _hash) public view returns (bool) {
        return _validHashes[account].contains(_hash);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        virtual
        override
        returns (ValidationData)
    {
        return VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        if (keccak256(data) != hash) return EIP1271_FAILED;
        if (isHash(sender, hash)) {
            return EIP1271_SUCCESS;
        } else {
            return EIP1271_FAILED;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function name() external pure virtual returns (string memory) {
        return "ERC1271PrehashValidator";
    }

    function isModuleType(uint256 isType) external pure virtual override returns (bool) {
        return isType == TYPE_VALIDATOR;
    }
}
