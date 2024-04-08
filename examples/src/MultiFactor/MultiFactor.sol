// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC7579ValidatorBase } from "modulekit/src/Modules.sol";
import { IERC7579Module } from "modulekit/src/external/ERC7579.sol";
import { IERC7579Account, Execution } from "modulekit/src/Accounts.sol";
import { PackedUserOperation } from "modulekit/src/external/ERC4337.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import { ECDSAFactor } from "./ECDSAFactor.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";

struct ConfigData {
    address subValidator;
    bytes initData;
}

contract MultiFactor is ERC7579ValidatorBase, ECDSAFactor {
    using LibSort for *;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidThreshold(uint256 length, uint256 threshold);
    error ValidatorIsAlreadyUsed(address smartaccount, address validator);
    error InvalidParams();
    error InvalidParamsLength();

    uint256 constant MIN_THRESHOLD = 2;

    struct MultiFactorConfig {
        uint8 threshold;
        address[] subValidators;
    }

    mapping(address smartAccount => MultiFactorConfig configuration) internal multiFactorConfig;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external {
        // check if module is already initialized
        if (data.length == 0) return;
        if (multiFactorConfig[msg.sender].threshold != 0) revert("Already Initialized");

        // TODO: slice this with packed / calldata
        (
            address[] memory subValidators,
            bytes[] memory deInitDatas,
            bytes[] memory initDatas,
            uint8 threshold
        ) = abi.decode(data, (address[], bytes[], bytes[], uint8));

        _setConfig(subValidators, deInitDatas, initDatas, threshold);
    }

    function onUninstall(bytes calldata deInit) external {
        // TODO: slice this with packed / calldata
        bytes[] memory deInitDatas;
        if (deInit.length != 0) {
            (deInitDatas) = abi.decode(deInit, (bytes[]));
        }
        MultiFactorConfig storage config = multiFactorConfig[msg.sender];
        _deinitSubValidator(msg.sender, config.subValidators, deInitDatas);
        config.subValidators = new address[](0);
        config.threshold = 0;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return multiFactorConfig[msg.sender].threshold != 0;
    }

    function setConfig(
        address[] memory subValidators,
        bytes[] memory deInitDatas,
        bytes[] memory initDatas,
        uint8 threshold
    )
        external
    {
        _setConfig(subValidators, deInitDatas, initDatas, threshold);
    }

    function getMultiFactorConfig(address smartAccount)
        external
        view
        returns (MultiFactorConfig memory)
    {
        return multiFactorConfig[smartAccount];
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
        // todo: slice index into sigs to save calldata
        // decode the selection data from userOp signature
        (uint256[] memory validatorIndextoUse, bytes[] memory signatures) =
            abi.decode(userOp.signature, (uint256[], bytes[]));

        MultiFactorConfig storage config = multiFactorConfig[userOp.sender];

        // a uniquified list of validators must be created for this. so that the frontend / user can
        // not select the same validator multiple times
        // not that this assumes that the subvalidators in storage are unique
        uint256 validatorToUseCount = validatorIndextoUse.length;

        uint256[] memory _validatorToUseCount = new uint256[](validatorToUseCount);
        for (uint256 i; i < validatorToUseCount; i++) {
            for (uint256 j; j < _validatorToUseCount.length; j++) {
                if (validatorIndextoUse[i] + 1 == _validatorToUseCount[j]) {
                    revert("index already used");
                }
            }
            _validatorToUseCount[i] = validatorIndextoUse[i] + 1;
        }
        // check that the number of signatures matches the number of validators
        // check validatorIndextoUse length is higher or equal to threshold.
        // should a smaller value be provided, the security assumption that a multifactor validator
        // is void
        if (validatorToUseCount < config.threshold || validatorToUseCount != signatures.length) {
            return VALIDATION_FAILED;
        }

        // initialize the min values
        uint256 validUntil;
        uint256 validAfter;
        bool sigFailed;
        // Iterate over the selected validators and validate the userOp.
        for (uint256 i; i < validatorToUseCount; i++) {
            ERC7579ValidatorBase _validator =
                ERC7579ValidatorBase(config.subValidators[validatorIndextoUse[i]]);

            // Since userOp.signature had the validatorIndexToUse encoded, we need to clean up the
            // signature field, before passing it to the validator
            ValidationData _validationData;
            // if the validator is this contract, we can use the local ECDAFactor implementation
            if (address(_validator) == address(this)) {
                _validationData = _checkSignature(userOpHash, signatures[i]);
            } else {
                userOp.signature = signatures[i];
                _validationData = _validator.validateUserOp(userOp, userOpHash);
            }

            // destructuring the individual return values from the subvalidator
            // using uint256 to avoid padding gas
            (bool _sigFailed, uint256 _validUntil, uint256 _validAfter) =
                _unpackValidationData(_validationData);

            // update the min values
            if (_validUntil < validUntil) validUntil = _validUntil;
            if (_validAfter > validAfter) validAfter = _validAfter;

            if (_sigFailed) sigFailed = true;
        }

        return _packValidationData({
            sigFailed: sigFailed,
            validUntil: uint48(validUntil),
            validAfter: uint48(validAfter)
        });
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
        // destructure data into validatorIndexToUse and signature
        // TODO: slice this with packed / calldata
        (uint256[] memory validatorIndextoUse, bytes[] memory signatures) =
            abi.decode(data, (uint256[], bytes[]));
        MultiFactorConfig storage config = multiFactorConfig[msg.sender];

        // a uniquified list of validators MUST be crated for this. so that the frontend / user can
        // not select the same validator multiple times
        uint256 validatorToUseCount = validatorIndextoUse.length;

        uint256[] memory _validatorToUseCount = new uint256[](validatorToUseCount);
        for (uint256 i; i < validatorToUseCount; i++) {
            for (uint256 j; j < _validatorToUseCount.length; j++) {
                if (validatorIndextoUse[i] + 1 == _validatorToUseCount[j]) {
                    revert("index already used");
                }
            }
            _validatorToUseCount[i] = validatorIndextoUse[i] + 1;
        }
        // check that the number of signatures matches the number of validators
        // check validatorIndextoUse length is higher or equal to threshold.
        // should a smaller value be provided, the security assumption that a multifactor validator
        // is void
        if (validatorToUseCount < config.threshold || validatorToUseCount != signatures.length) {
            return EIP1271_FAILED;
        }

        // iterate over subValidators[]
        for (uint256 i; i < validatorToUseCount; i++) {
            ERC7579ValidatorBase _validator =
                ERC7579ValidatorBase(config.subValidators[validatorIndextoUse[i]]);

            // check if local ECSDSA should be used
            if (useLocalECDSAFactor(address(_validator))) {
                // return EIP1271_FAILED if the signature is invalid
                if (!_isValidSignature(hash, signatures[i])) return EIP1271_FAILED;
            } else {
                // get ERC1271 return value from subvalidator
                bytes4 subValidatorERC1271 =
                    _validator.isValidSignatureWithSender(sender, hash, signatures[i]);
                // check if return value is ERC1271 magic value. if not, return fail
                if (subValidatorERC1271 != EIP1271_SUCCESS) return EIP1271_FAILED;
            }
        }

        // if we got to this stage, all subvalidators were able to correctly validate their
        // signatures
        return EIP1271_SUCCESS;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Helper function that will call `onInstall` on selected subvalidators
     * @dev If a subvalidator is already used by the smart account, this function will revert, as
     * configuring the validator in a new setting could brick the account
     * @param _smartAccount smartaccount address for which the MFA is used
     * @param subValidators list of subvalidators to be configured on the account
     * @param datas init datas for the subvalidators
     */
    function _initSubValidator(
        address _smartAccount,
        address[] memory subValidators,
        bytes[] memory datas
    )
        internal
    {
        IERC7579Account smartAccount = IERC7579Account(_smartAccount);
        uint256 length = subValidators.length;

        bool noInitData = datas.length == 0;
        if (length != datas.length && noInitData) revert InvalidParams();
        Execution[] memory subValidatorInits = new Execution[](length);
        // iterate over subValidators[]
        for (uint256 i; i < length; i++) {
            address subValidator = subValidators[i];

            // should the selected subvalidator be address(this), the user is intending to use the
            // ECDSA recover feature
            // available in ECDSAFactor.
            if (subValidator == address(this)) {
                subValidatorInits[i] = Execution({
                    target: address(this),
                    value: 0,
                    callData: abi.encodeCall(
                        ECDSAFactor.setECDSAFactor, (abi.decode(datas[i], (FactorConfig)))
                    )
                });
            }
            // only allow the installation of subvalidators, if the validator module is not
            // already installed on the account
            else if (!smartAccount.isModuleInstalled(TYPE_VALIDATOR, subValidator, "")) {
                if (datas[i].length != 0) {
                    // this is NOT installing the module on the account, but rather initing it
                    subValidatorInits[i] = Execution({
                        target: subValidator,
                        value: 0,
                        callData: abi.encodeCall(IERC7579Module.onInstall, (datas[i]))
                    });
                }
            }
        }

        // execute batched transaction that will initialize the subValidators
        smartAccount.executeFromExecutor(
            ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(subValidatorInits)
        );
    }

    function _deinitSubValidator(
        address _smartAccount,
        address[] memory subValidators,
        bytes[] memory deInitDatas
    )
        internal
    {
        uint256 length = deInitDatas.length;

        // Ensure that the deinit data length matches with the number of currently configured
        // subvalidators.
        // Every subvalidator MUST be de-initialized to prevert weird states
        Execution[] memory subValidatorInits = new Execution[](length);

        // Iterate over all currently configured subvalidators and prepare a batched exec to de-init
        // them
        for (uint256 i; i < length; i++) {
            address subValidator = subValidators[i];
            // should the selected subvalidator be address(this), the user is intending to remove
            // the ECDSA recover feature available in ECDSAFactor.
            if (subValidator == address(this)) {
                // null out all values
                FactorConfig memory ecdsaConfig =
                    FactorConfig({ signer: address(0), validAfter: 0, validBefore: 0 });
                subValidatorInits[i] = Execution({
                    target: address(this),
                    value: 0,
                    callData: abi.encodeCall(ECDSAFactor.setECDSAFactor, (ecdsaConfig))
                });
            } else {
                if (deInitDatas[i].length != 0) {
                    // this is NOT uninstalling the module on the account, but rather
                    // de-initializeing
                    subValidatorInits[i] = Execution({
                        target: subValidator,
                        value: 0,
                        callData: abi.encodeCall(IERC7579Module.onUninstall, (deInitDatas[i]))
                    });
                }
            }
        }

        // execute batched transaction that will de-initialize the subValidators
        IERC7579Account(_smartAccount).executeFromExecutor(
            ModeLib.encodeSimpleBatch(), ExecutionLib.encodeBatch(subValidatorInits)
        );
    }

    // TODO: 1 add registry check for subValidators.
    //          This should also make sure that the subValidator is actually a validator
    function _setConfig(
        address[] memory subValidators,
        bytes[] memory deInitDatas,
        bytes[] memory initDatas,
        uint8 threshold
    )
        internal
    {
        uint256 length = subValidators.length;
        // sort and uniquify the subValidators
        // Should a user provide the same validators multiple times, the security assumption that a
        // multifactor validator brings can be bypassed
        address[] memory _subValidators = new address[](length);
        for (uint256 i; i < length; i++) {
            for (uint256 j; j < _subValidators.length; j++) {
                if (subValidators[i] == _subValidators[j]) {
                    revert("validator already used");
                }
            }
            _subValidators[i] = subValidators[i];
        }
        if (length < threshold && threshold >= MIN_THRESHOLD) {
            revert InvalidThreshold(length, threshold);
        }
        if (length != initDatas.length) revert InvalidParamsLength();
        if (length != deInitDatas.length) revert InvalidParamsLength();
        _deinitSubValidator(msg.sender, subValidators, deInitDatas);
        _initSubValidator(msg.sender, subValidators, initDatas);

        MultiFactorConfig storage config = multiFactorConfig[msg.sender];
        config.subValidators = subValidators;
        config.threshold = threshold;
    }

    function useLocalECDSAFactor(address validator) internal view returns (bool) {
        return validator == address(this);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256 typeID) external pure returns (bool) {
        if (typeID == TYPE_VALIDATOR) return true;
        if (typeID == TYPE_EXECUTOR) return true;
    }

    function name() external pure returns (string memory) {
        return "MultiFactor";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }
}
