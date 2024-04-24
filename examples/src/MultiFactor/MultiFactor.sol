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

    struct Validator {
        bytes32 packedValidatorAndId; // abi.encodePacked(uint92(id), address(validator))
        bytes data;
    }

    struct SubValidatorData {
        mapping(uint256 id => mapping(address account => bytes data)) validatorData;
    }

    struct MFAConfig {
        uint8 threshold;
        uint128 iteration;
    }

    mapping(address account => MFAConfig config) public accountConfig;
    mapping(uint256 iteration => mapping(address subValidator => SubValidatorData data)) internal
        validatorData;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    IERC7484 public immutable REGISTRY;

    constructor(IERC7484 _registry) {
        REGISTRY = _registry;
    }

    // function _validatorData(
    //     address subValidator,
    //     uint256 id,
    //     address account
    // )
    //     internal
    //     view
    //     returns (bytes memory)
    // {
    //     SubValidators storage subValidators = validatorData[subValidator];
    //     return subValidators.validatorData[subValidators.iteration][id][account];
    // }

    function $subValidatorData(
        address account,
        uint256 iteration,
        address subValidator,
        uint96 id
    )
        internal
        returns (bytes storage $validatorData)
    {
        return validatorData[iteration][subValidator].validatorData[iteration][account];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        address account = msg.sender;
        if (isInitialized(account)) revert AlreadyInitialized(account);

        (Validator[] memory validators, uint8 threshold) = abi.decode(data, (Validator[], uint8));
        uint256 length = validators.length;
        if (length < threshold) revert InvalidThreshold(length, threshold);
        MFAConfig storage $config = accountConfig[account];
        uint256 iteration = $config.iteration;
        $config.threshold = threshold;

        for (uint256 i; i < length; i++) {
            Validator memory _validator = validators[i];
            (address validatorAddress, uint96 id) =
                _decodeValidatorAndId(_validator.packedValidatorAndId);
            // get storage reference to validator data slot
            bytes storage $validatorData = $subValidatorData({
                account: account,
                iteration: iteration,
                subValidator: validatorAddress,
                id: id
            });

            REGISTRY.checkForAccount({
                smartAccount: account,
                module: validatorAddress,
                moduleType: MODULE_TYPE_VALIDATOR
            });
            $validatorData = _validator.data;

            emit ValidatorAdded(account, validatorAddress, id, iteration);
        }
    }

    function onUninstall(bytes calldata) external {
        address account = msg.sender;
        MFAConfig storage $config = accountConfig[account];
        uint256 _newIteration = $config.iteration + 1;
        delete $config.threshold;
        $config.iteration = _newIteration;

        emit IterationIncreased(account, _newIteration);
    }

    function isInitialized(address account) public view returns (bool) {
        MFAConfig storage $config = accountConfig[account];
        return $config.threshold != 0;
    }

    function addValidator(
        address validatorAddress,
        uint96 id,
        bytes calldata newValidatorData
    )
        external
    {
        address account = msg.sender;
        MFAConfig storage $config = accountConfig[account];
        uint256 iteration = $config.iteration;

        REGISTRY.checkForAccount({
            smartAccount: msg.sender,
            module: validatorAddress,
            moduleType: MODULE_TYPE_VALIDATOR
        });

        bytes storage $validatorData = $subValidatorData({
            account: account,
            iteration: iteration,
            subValidator: validatorAddress,
            id: id
        });
        $validatorData = newValidatorData;

        emit ValidatorAdded(account, validatorAddress, id, iteration);
    }

    function removeValidator(address validatorAddress, uint96 id) external {
        address account = msg.sender;
        MFAConfig storage $config = accountConfig[account];
        uint256 iteration = $config.iteration;
        bytes storage $validatorData = $subValidatorData({
            account: account,
            iteration: iteration,
            subValidator: validatorAddress,
            id: id
        });

        delete $validatorData;

        emit ValidatorRemoved(account, validatorAddress, id, iteration);
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

        uint256 validCount;

        for (uint256 i; i < validatorsLength; i++) {
            Validator memory validator = validators[i];

            (address validatorAddress, uint96 id) =
                _decodeValidatorAndId(validator.packedValidatorAndId);

            bytes storage $validatorData = $subValidatorData({
                account: account,
                iteration: iteration,
                subValidator: validatorAddress,
                id: id
            });

            bool isValid = IStatelessValidator(validatorAddress).validateSignatureWithData({
                hash: hash,
                signature: validator.data,
                data: $
            });
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
