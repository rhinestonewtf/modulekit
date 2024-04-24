// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";
import { IStatelessValidator } from "modulekit/src/interfaces/IStatelessValidator.sol";
import { IERC7484 } from "modulekit/src/interfaces/IERC7484.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/src/external/ERC7579.sol";
import "./DataTypes.sol";
import { MultiFactorLib } from "./MultiFactorLib.sol";
import "forge-std/console2.sol";

contract MultiFactor is ERC7579ValidatorBase {
    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidThreshold(uint256 length, uint256 threshold);
    error InvalidParamsLength();
    error InvalidValidator(address account, address subValidator, validatorId id);

    event ValidatorAdded(
        address indexed smartAccount, address indexed validator, validatorId id, uint256 iteration
    );
    event ValidatorRemoved(
        address indexed smartAccount, address indexed validator, validatorId id, uint256 iteration
    );
    event IterationIncreased(address indexed smartAccount, uint256 iteration);

    mapping(address account => MFAConfig config) public accountConfig;
    mapping(
        uint256 iteration => mapping(address subValidator => IterativeSubvalidatorRecord record)
    ) internal iterationToSubValidator;

    IERC7484 public immutable REGISTRY;

    constructor(IERC7484 _registry) {
        REGISTRY = _registry;
    }

    function $subValidatorData(
        address account,
        uint256 iteration,
        address subValidator,
        validatorId id
    )
        internal
        view
        returns (SubValidatorConfig storage $validatorData)
    {
        return iterationToSubValidator[iteration][subValidator].subValidators[id][account];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        address account = msg.sender;
        if (isInitialized(account)) revert AlreadyInitialized(account);
        // abi.encodePacked(uint8 threshold, abi.encode(Validator[]))
        uint8 threshold = uint8(bytes1(data[:1]));
        Validator[] calldata validators = MultiFactorLib.decode(data[1:]);
        uint256 length = validators.length;
        if (length < threshold) revert InvalidThreshold(length, threshold);
        MFAConfig storage $config = accountConfig[account];
        uint256 iteration = $config.iteration;
        $config.threshold = threshold;

        for (uint256 i; i < length; i++) {
            Validator calldata _validator = validators[i];

            (address validatorAddress, validatorId id) =
                MultiFactorLib.unpack(_validator.packedValidatorAndId);
            // get storage reference to sub validator config
            SubValidatorConfig storage $validator = $subValidatorData({
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
            // SSTORE new validator data
            $validator.data = _validator.data;

            emit ValidatorAdded(account, validatorAddress, id, iteration);
        }
    }

    function onUninstall(bytes calldata) external {
        address account = msg.sender;
        MFAConfig storage $config = accountConfig[account];
        uint256 _newIteration = $config.iteration + 1;
        delete $config.threshold;
        $config.iteration = uint128(_newIteration);

        emit IterationIncreased(account, _newIteration);
    }

    function isInitialized(address account) public view returns (bool) {
        MFAConfig storage $config = accountConfig[account];
        return $config.threshold != 0;
    }

    function isSubValidator(
        address account,
        address subValidator,
        validatorId id
    )
        external
        view
        returns (bool)
    {
        MFAConfig storage $config = accountConfig[account];

        SubValidatorConfig storage $validator = $subValidatorData({
            account: account,
            iteration: $config.iteration,
            subValidator: subValidator,
            id: id
        });
        return $validator.data.length != 0;
    }

    function setValidator(
        address validatorAddress,
        validatorId id,
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

        SubValidatorConfig storage $validator = $subValidatorData({
            account: account,
            iteration: iteration,
            subValidator: validatorAddress,
            id: id
        });
        $validator.data = newValidatorData;

        emit ValidatorAdded(account, validatorAddress, id, iteration);
    }

    function rmValidator(address validatorAddress, validatorId id) external {
        address account = msg.sender;
        MFAConfig storage $config = accountConfig[account];
        uint256 iteration = $config.iteration;
        SubValidatorConfig storage $validator = $subValidatorData({
            account: account,
            iteration: iteration,
            subValidator: validatorAddress,
            id: id
        });

        delete $validator.data;

        emit ValidatorRemoved(account, validatorAddress, id, iteration);
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
        Validator[] calldata validators = MultiFactorLib.decode(userOp.signature);

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
        Validator[] calldata validators = MultiFactorLib.decode(data);

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
        Validator[] calldata validators,
        bytes32 hash
    )
        internal
        view
        returns (bool)
    {
        uint256 validatorsLength = validators.length;
        if (validatorsLength == 0) revert InvalidParamsLength();

        MFAConfig storage $config = accountConfig[msg.sender];
        uint256 iteration = $config.iteration;
        uint256 requiredThreshold = $config.threshold;

        uint256 validCount;

        for (uint256 i; i < validatorsLength; i++) {
            Validator calldata validator = validators[i];

            (address validatorAddress, validatorId id) =
                MultiFactorLib.unpack(validator.packedValidatorAndId);

            SubValidatorConfig storage $validator = $subValidatorData({
                account: msg.sender,
                iteration: iteration,
                subValidator: validatorAddress,
                id: id
            });

            bytes memory validatorStorageData = $validator.data;
            if (validatorStorageData.length == 0) {
                revert InvalidValidator(msg.sender, validatorAddress, id);
            }

            bool isValid = IStatelessValidator(validatorAddress).validateSignatureWithData({
                hash: hash,
                signature: validator.data,
                data: validatorStorageData
            });
            if (isValid) {
                validCount++;
            }
        }
        if (validCount < requiredThreshold) return false;
        else return true;
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
