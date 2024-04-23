// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";
import { IStatelessValidator } from "modulekit/src/interfaces/IStatelessValidator.sol";

contract MultiFactor is ERC7579ValidatorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidThreshold(uint256 length, uint256 threshold);
    error ValidatorIsAlreadyUsed(address smartaccount, address validator);
    error InvalidParams();
    error InvalidParamsLength();

    event ValidatorAdded(
        address indexed smartAccount, address indexed validator, uint256 id, uint8 iteration
    );
    event ValidatorRemoved(
        address indexed smartAccount, address indexed validator, uint256 id, uint8 iteration
    );
    event IterationIncreased(address indexed smartAccount, uint8 iteration);

    struct Config {
        uint32 iteration;
        uint8 threshold;
    }

    struct Validator {
        address validatorAddress;
        uint96 id;
        bytes validatorData;
    }

    struct ValidatorToUse {
        address validatorAddress;
        uint96 id;
        bytes signature;
    }

    // account => threshold
    mapping(address account => Config) public config;
    // validator => account => validatorData
    mapping(
        uint32 iteration
            => mapping(
                address validatorAddress => mapping(uint96 id => mapping(address account => bytes))
            )
    ) public validatorData;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        address account = msg.sender;
        if (isInitialized(account)) revert AlreadyInitialized(account);

        (Validator[] memory validators, uint8 threshold) = abi.decode(data, (Validator[], uint8));

        uint32 iteration = config[account].iteration;
        uint256 length = validators.length;

        if (length < threshold) revert InvalidThreshold(length, threshold);

        for (uint256 i; i < length; i++) {
            // TODO: check registry

            Validator memory validator = validators[i];
            validatorData[iteration][validator.validatorAddress][validator.id][account] =
                validator.validatorData;
        }

        config[account].threshold = threshold;
    }

    function onUninstall(bytes calldata) external {
        // TODO
        address account = msg.sender;

        config[account].threshold = 0;
        config[account].iteration++;
    }

    function isInitialized(address account) public view returns (bool) {
        return config[account].threshold != 0;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function validateUserOp(
        PackedUserOperation memory userOp,
        bytes32 userOpHash
    )
        external
        virtual
        override
        returns (ValidationData)
    {
        (ValidatorToUse[] memory validatorsToUse) = abi.decode(userOp.signature, (ValidatorToUse[]));

        bool isValid = _validateSignatureWithConfig(validatorsToUse, userOpHash);

        if (isValid) {
            return VALIDATION_SUCCESS;
        }
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
        (ValidatorToUse[] memory validatorsToUse) = abi.decode(data, (ValidatorToUse[]));

        bool isValid = _validateSignatureWithConfig(validatorsToUse, hash);

        if (isValid) {
            return EIP1271_SUCCESS;
        }
        return EIP1271_FAILED;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _validateSignatureWithConfig(
        ValidatorToUse[] memory validatorsToUse,
        bytes32 hash
    )
        internal
        view
        returns (bool)
    {
        uint256 validatorsLength = validatorsToUse.length;
        if (validatorsLength == 0) revert InvalidParamsLength();

        address account = msg.sender;
        uint32 iteration = config[account].iteration;

        uint256 validCount;

        for (uint256 i; i < validatorsLength; i++) {
            ValidatorToUse memory validatorToUse = validatorsToUse[i];

            bytes memory _validatorData = validatorData[iteration][validatorToUse.validatorAddress][validatorToUse
                .id][account];

            bool isValid = IStatelessValidator(validatorToUse.validatorAddress)
                .validateSignatureWithData(hash, validatorToUse.signature, _validatorData);

            if (isValid) {
                validCount++;
            }
        }

        if (validCount >= config[account].threshold) {
            return true;
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function name() external pure returns (string memory) {
        return "MultiFactor";
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }
}
