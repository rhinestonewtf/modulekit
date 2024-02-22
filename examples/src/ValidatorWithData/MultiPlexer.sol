// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { PackedUserOperation } from "@rhinestone/modulekit/src/external/ERC4337.sol";

import { SentinelList4337Lib } from "sentinellist/SentinelList4337.sol";

import { SignatureCheckerLib } from "solady/src/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { EncodedModuleTypes, ModuleTypeLib, ModuleType } from "erc7579/lib/ModuleTypeLib.sol";

interface StatelessValidator {
    function validateUserOpWithData(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        bytes calldata data
    )
        external
        returns (uint256);
}

contract SubValidator is ERC7579ValidatorBase {
    using SentinelList4337Lib for SentinelList4337Lib.SentinelList;
    using SignatureCheckerLib for address;

    mapping(address subValidator => mapping(address smartAccount => bytes dataForSubValidator))
        internal $subvalidatorDatas;
    mapping(address smartAccount => address[] subValidators) internal $subValidators;

    function onInstall(bytes calldata data) external override { }

    function onUninstall(bytes calldata) external override { }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        virtual
        override
        returns (ValidationData ret)
    {
        address smartAccount = userOp.sender;
        uint256 length = $subValidators[smartAccount].length;
        for (uint256 i; i < length; i++) {
            address validator = $subValidators[smartAccount][i];
            bytes memory validationParam = $subvalidatorDatas[validator][smartAccount];
            StatelessValidator(validator).validateUserOpWithData(
                userOp, userOpHash, validationParam
            );
        }
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
    { }

    function name() external pure returns (string memory) {
        return "OwnableValidator";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function getModuleTypes() external view returns (EncodedModuleTypes) { }

    function isInitialized(address smartAccount) external view returns (bool) { }
}
