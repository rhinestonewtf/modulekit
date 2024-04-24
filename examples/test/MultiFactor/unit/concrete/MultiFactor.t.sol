// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import {
    MultiFactor,
    ERC7579ValidatorBase,
    Validator,
    ValidatorId
} from "src/MultiFactor/MultiFactor.sol";
import { IERC7579Module } from "modulekit/src/external/ERC7579.sol";
import {
    PackedUserOperation,
    getEmptyUserOperation,
    parseValidationData,
    ValidationData
} from "test/utils/ERC4337.sol";
import { MockRegistry } from "test/mocks/MockRegistry.sol";
import { MockValidator } from "test/mocks/MockValidator.sol";
import { EIP1271_MAGIC_VALUE } from "test/utils/Constants.sol";

contract MultiFactorTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    MultiFactor internal validator;
    MockRegistry internal _registry;
    MockValidator internal subValidator1;
    MockValidator internal subValidator2;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint8 _threshold = 2;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();

        _registry = new MockRegistry();
        validator = new MultiFactor(_registry);

        subValidator1 = new MockValidator();
        subValidator2 = new MockValidator();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getValidators() internal returns (Validator[] memory validators) {
        validators = new Validator[](2);
        validators[0] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(0), address(subValidator1))),
            data: hex"41414141"
        });
        validators[1] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(0), address(subValidator2))),
            data: hex"42424242"
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        Validator[] memory validators = _getValidators();
        bytes memory data = abi.encodePacked(_threshold, abi.encode(validators));

        validator.onInstall(data);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.AlreadyInitialized.selector, address(this))
        );
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_ThresholdIs0() public whenModuleIsNotIntialized {
        // it should revert
        Validator[] memory validators = _getValidators();
        bytes memory data = abi.encodePacked(uint8(0), abi.encode(validators));

        vm.expectRevert(abi.encodeWithSelector(MultiFactor.ZeroThreshold.selector));
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_OwnersLengthIsLessThanThreshold()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
    {
        // it should revert
        Validator[] memory validators = _getValidators();
        bytes memory data = abi.encodePacked(uint8(3), abi.encode(validators));

        vm.expectRevert(abi.encodeWithSelector(MultiFactor.InvalidThreshold.selector, 2, 3));
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_AValidatorIsNotAttestedTo()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenOwnersLengthIsNotLessThanThreshold
    {
        // it should revert
        Validator[] memory validators = _getValidators();
        validators[0].packedValidatorAndId = bytes32(abi.encodePacked(uint96(1), address(0x420)));
        bytes memory data = abi.encodePacked(_threshold, abi.encode(validators));

        vm.expectRevert();
        validator.onInstall(data);
    }

    function test_OnInstallWhenAllValidatorsAreAttestedTo()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenOwnersLengthIsNotLessThanThreshold
    {
        // it should set threshold
        // it should store the validators
        // it should emit a ValidatorAdded event for each validator
        Validator[] memory validators = _getValidators();
        bytes memory data = abi.encodePacked(_threshold, abi.encode(validators));

        vm.expectEmit(true, true, true, true, address(validator));
        emit MultiFactor.ValidatorAdded({
            smartAccount: address(this),
            validator: address(subValidator1),
            id: ValidatorId.wrap(bytes12(0)),
            iteration: 0
        });

        validator.onInstall(data);

        (uint8 threshold, uint128 iteration) = validator.accountConfig(address(this));
        assertEq(threshold, _threshold);

        bool isSubValidator1 = validator.isSubValidator(
            address(this), address(subValidator1), ValidatorId.wrap(bytes12(0))
        );
        assertTrue(isSubValidator1);

        bool isSubValidator2 = validator.isSubValidator(
            address(this), address(subValidator2), ValidatorId.wrap(bytes12(0))
        );
        assertTrue(isSubValidator2);
    }

    function test_OnUninstallShouldIncrementTheIterator() public {
        // it should increment the iterator
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        validator.onUninstall("");

        (uint8 threshold, uint128 iteration) = validator.accountConfig(address(this));
        assertEq(iteration, 1);
    }

    function test_OnUninstallShouldSetThresholdTo0() public {
        // it should set threshold to 0
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        validator.onUninstall("");

        (uint8 threshold, uint128 iteration) = validator.accountConfig(address(this));
        assertEq(threshold, uint8(0));
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool isInitialized = validator.isInitialized(address(this));
        assertFalse(isInitialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        bool isInitialized = validator.isInitialized(address(this));
        assertTrue(isInitialized);
    }

    function test_SetThresholdRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        validator.setThreshold(1);
    }

    function test_SetThresholdRevertWhen_ThresholdIs0() public whenModuleIsIntialized {
        // it should revert
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        vm.expectRevert(abi.encodeWithSelector(MultiFactor.ZeroThreshold.selector));
        validator.setThreshold(0);
    }

    function test_SetThresholdWhenThresholdIsNot0() public whenModuleIsIntialized {
        // it should set the threshold
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        uint8 newThreshold = 1;
        validator.setThreshold(newThreshold);

        (uint8 threshold,) = validator.accountConfig(address(this));
        assertEq(threshold, newThreshold);
    }

    function test_SetValidatorRevertWhen_ModuleIsNotIntialized() public {
        // it should revert

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        validator.setValidator(
            address(subValidator1), ValidatorId.wrap(bytes12(uint96(1))), hex"41414141"
        );
    }

    function test_SetValidatorWhenModuleIsIntialized() public {
        // it should emit a ValidatorAdded event
        // it should set the validator data
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        vm.expectEmit(true, true, true, true, address(validator));
        emit MultiFactor.ValidatorAdded({
            smartAccount: address(this),
            validator: address(subValidator1),
            id: ValidatorId.wrap(bytes12(uint96(1))),
            iteration: 0
        });

        validator.setValidator(
            address(subValidator1), ValidatorId.wrap(bytes12(uint96(1))), hex"41414141"
        );

        bool isValidator = validator.isSubValidator(
            address(this), address(subValidator1), ValidatorId.wrap(bytes12(uint96(1)))
        );
        assertTrue(isValidator);
    }

    function test_RemoveValidatorRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );

        validator.removeValidator(address(subValidator1), ValidatorId.wrap(bytes12(uint96(0))));
    }

    function test_RemoveValidatorWhenModuleIsIntialized() public {
        // it should emit a ValidatorRemoved event
        // it should remove the validator
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        vm.expectEmit(true, true, true, true, address(validator));
        emit MultiFactor.ValidatorRemoved({
            smartAccount: address(this),
            validator: address(subValidator1),
            id: ValidatorId.wrap(bytes12(0)),
            iteration: 0
        });

        validator.removeValidator(address(subValidator1), ValidatorId.wrap(bytes12(0)));

        bool isSubValidator = validator.isSubValidator(
            address(this), address(subValidator1), ValidatorId.wrap(bytes12(0))
        );
        assertFalse(isSubValidator);
    }

    function test_IsSubValidatorWhenSubvalidatorIsNotInstalled() public {
        // it should return false
        bool isSubValidator = validator.isSubValidator(
            address(this), address(subValidator1), ValidatorId.wrap(bytes12(0))
        );
        assertFalse(isSubValidator);
    }

    function test_IsSubValidatorWhenSubvalidatorIsInstalled() public {
        // it should return true
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        bool isSubValidator = validator.isSubValidator(
            address(this), address(subValidator1), ValidatorId.wrap(bytes12(0))
        );
        assertTrue(isSubValidator);
    }

    function test_ValidateUserOpWhenValidatorLengthIsZero() public {
        // it should return 1
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenAnyValidatorIsNotSet() public whenValidatorLengthIsNotZero {
        // it should return 1
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        PackedUserOperation memory userOp = getEmptyUserOperation();

        Validator[] memory validators = _getValidators();
        validators[1].packedValidatorAndId =
            bytes32(abi.encodePacked(bytes12(uint96(1)), address(0x420)));

        userOp.signature = abi.encode(validators);
        userOp.sender = address(this);

        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenValidSignaturesAreLessThanThreshold()
        public
        whenValidatorLengthIsNotZero
        whenAllValidatorsAreSet
    {
        // it should return 1
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        PackedUserOperation memory userOp = getEmptyUserOperation();

        Validator[] memory validators = _getValidators();
        validators[1].data = bytes("invalid");

        userOp.signature = abi.encode(validators);
        userOp.sender = address(this);

        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenValidSignaturesAreGreaterThanThreshold()
        public
        whenValidatorLengthIsNotZero
        whenAllValidatorsAreSet
    {
        // it should return 0
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        PackedUserOperation memory userOp = getEmptyUserOperation();

        Validator[] memory validators = _getValidators();

        userOp.signature = abi.encode(validators);
        userOp.sender = address(this);

        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 0);
    }

    function test_IsValidSignatureWithSenderWhenValidatorLengthIsZero() public {
        // it should return EIP1271_FAILED
        Validator[] memory validators = _getValidators();

        bytes32 hash = bytes32(keccak256("hash"));

        bytes4 result =
            validator.isValidSignatureWithSender(address(1), hash, abi.encode(validators));
        assertNotEq(result, EIP1271_MAGIC_VALUE);
    }

    function test_IsValidSignatureWithSenderWhenAnyValidatorIsNotSet()
        public
        whenValidatorLengthIsNotZero
    {
        // it should return EIP1271_FAILED
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        Validator[] memory validators = _getValidators();
        validators[1].packedValidatorAndId =
            bytes32(abi.encodePacked(bytes12(uint96(1)), address(0x420)));

        bytes32 hash = bytes32(keccak256("hash"));

        bytes4 result =
            validator.isValidSignatureWithSender(address(1), hash, abi.encode(validators));
        assertNotEq(result, EIP1271_MAGIC_VALUE);
    }

    function test_IsValidSignatureWithSenderWhenValidSignaturesAreLessThanThreshold()
        public
        whenValidatorLengthIsNotZero
        whenAllValidatorsAreSet
    {
        // it should return EIP1271_FAILED
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        Validator[] memory validators = _getValidators();
        validators[1].data = bytes("invalid");

        bytes32 hash = bytes32(keccak256("hash"));

        bytes4 result =
            validator.isValidSignatureWithSender(address(1), hash, abi.encode(validators));
        assertNotEq(result, EIP1271_MAGIC_VALUE);
    }

    function test_IsValidSignatureWithSenderWhenValidSignaturesAreGreaterThanThreshold()
        public
        whenValidatorLengthIsNotZero
        whenAllValidatorsAreSet
    {
        // it should return ERC1271_MAGIC_VALUE
        test_OnInstallWhenAllValidatorsAreAttestedTo();

        Validator[] memory validators = _getValidators();

        bytes32 hash = bytes32(keccak256("hash"));

        bytes4 result =
            validator.isValidSignatureWithSender(address(1), hash, abi.encode(validators));
        assertEq(result, EIP1271_MAGIC_VALUE);
    }

    function test_NameShouldReturnMultiFactor() public {
        // it should return MultiFactor
        string memory name = validator.name();
        assertEq(name, "MultiFactor");
    }

    function test_VersionShouldReturn100() public {
        // it should return 1.0.0
        string memory version = validator.version();
        assertEq(version, "1.0.0");
    }

    function test_IsModuleTypeWhenTypeIDIs1() public {
        // it should return true
        bool isModuleType = validator.isModuleType(1);
        assertTrue(isModuleType);
    }

    function test_IsModuleTypeWhenTypeIDIsNot1() public {
        // it should return false
        bool isModuleType = validator.isModuleType(2);
        assertFalse(isModuleType);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenModuleIsNotIntialized() {
        _;
    }

    modifier whenThresholdIsNot0() {
        _;
    }

    modifier whenOwnersLengthIsNotLessThanThreshold() {
        _;
    }

    modifier whenModuleIsIntialized() {
        _;
    }

    modifier whenValidatorLengthIsNotZero() {
        _;
    }

    modifier whenAllValidatorsAreSet() {
        _;
    }
}
