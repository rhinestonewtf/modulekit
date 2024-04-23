// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";
import { IStatelessValidator } from "modulekit/src/interfaces/IStatelessValidator.sol";
import { IERC7484 } from "modulekit/src/interfaces/IERC7484.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/src/external/ERC7579.sol";

contract MultiFactor is ERC7579ValidatorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidThreshold(uint256 length, uint256 threshold);
    error InvalidParamsLength();

    event ValidatorAdded(
        address indexed smartAccount, address indexed validator, uint256 id, uint256 iteration
    );
    event ValidatorRemoved(
        address indexed smartAccount, address indexed validator, uint256 id, uint256 iteration
    );
    event IterationIncreased(address indexed smartAccount, uint256 iteration);

    struct Config {
        uint32 iteration;
        uint8 threshold;
    }

    struct Validator {
        bytes32 validatorAndId; // abi.encodePacked(uint92(id), address(validator))
        bytes data;
    }

    // account => Config
    mapping(address account => Config) public config;
    // iteration => validatorAddress => id => account => data
    mapping(
        uint256 iteration
            => mapping(
                address validatorAddress => mapping(uint256 id => mapping(address account => bytes))
            )
    ) public validatorData;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    IERC7484 public immutable registry;

    constructor(IERC7484 _registry) {
        registry = _registry;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        address account = msg.sender;
        if (isInitialized(account)) revert AlreadyInitialized(account);

        (Validator[] memory validators, uint8 threshold) = abi.decode(data, (Validator[], uint8));

        uint256 iteration = config[account].iteration;
        uint256 length = validators.length;

        if (length < threshold) revert InvalidThreshold(length, threshold);

        for (uint256 i; i < length; i++) {
            Validator memory validator = validators[i];
            (address validatorAddress, uint96 id) = _decodeValidatorAndId(validator.validatorAndId);

            registry.checkForAccount({
                smartAccount: msg.sender,
                module: validatorAddress,
                moduleType: MODULE_TYPE_VALIDATOR
            });

            validatorData[iteration][validatorAddress][id][account] = validator.data;

            emit ValidatorAdded(account, validatorAddress, id, iteration);
        }

        config[account].threshold = threshold;
    }

    function onUninstall(bytes calldata) external {
        address account = msg.sender;

        config[account].threshold = 0;
        config[account].iteration++;

        emit IterationIncreased(account, config[account].iteration);
    }

    function isInitialized(address account) public view returns (bool) {
        return config[account].threshold != 0;
    }

    function addValidator(
        address _validatorAddress,
        uint96 _id,
        bytes calldata _validatorData
    )
        external
    {
        address account = msg.sender;
        uint256 iteration = config[account].iteration;

        registry.checkForAccount({
            smartAccount: msg.sender,
            module: _validatorAddress,
            moduleType: MODULE_TYPE_VALIDATOR
        });

        validatorData[iteration][_validatorAddress][_id][account] = _validatorData;

        emit ValidatorAdded(account, _validatorAddress, _id, iteration);
    }

    function removeValidator(address _validatorAddress, uint96 _id) external {
        address account = msg.sender;
        uint256 iteration = config[account].iteration;

        delete validatorData[iteration][_validatorAddress][_id][account];

        emit ValidatorRemoved(account, _validatorAddress, _id, iteration);
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
        (Validator[] memory validators) = abi.decode(userOp.signature, (Validator[]));

        bool isValid = _validateSignatureWithConfig(validators, userOpHash);

        if (isValid) {
            return VALIDATION_SUCCESS;
        }
        return VALIDATION_FAILED;
    }

    function isValidSignatureWithSender(
        address,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        (Validator[] memory validators) = abi.decode(data, (Validator[]));

        bool isValid = _validateSignatureWithConfig(validators, hash);

        if (isValid) {
            return EIP1271_SUCCESS;
        }
        return EIP1271_FAILED;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _validateSignatureWithConfig(
        Validator[] memory validators,
        bytes32 hash
    )
        internal
        view
        returns (bool)
    {
        uint256 validatorsLength = validators.length;
        if (validatorsLength == 0) revert InvalidParamsLength();

        address account = msg.sender;
        uint256 iteration = config[account].iteration;

        uint256 validCount;

        for (uint256 i; i < validatorsLength; i++) {
            Validator memory validator = validators[i];

            (address validatorAddress, uint96 id) = _decodeValidatorAndId(validator.validatorAndId);

            bytes memory _validatorData = validatorData[iteration][validatorAddress][id][account];

            bool isValid = IStatelessValidator(validatorAddress).validateSignatureWithData(
                hash, validator.data, _validatorData
            );

            if (isValid) {
                validCount++;
            }
        }

        if (validCount >= config[account].threshold) {
            return true;
        }
        return false;
    }

    function _decodeValidatorAndId(bytes32 validatorAndId)
        internal
        pure
        returns (address, uint96)
    {
        // validatorAndId = abi.encodePacked(uint96(id), address(validator))
        return (address(bytes20(validatorAndId)), uint96(uint256(validatorAndId)));
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
