// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest, console2 } from "test/Base.t.sol";
import { OwnableValidator, ERC7579ValidatorBase } from "src/OwnableValidator/OwnableValidator.sol";
import { IERC7579Module } from "modulekit/src/external/ERC7579.sol";
import { PackedUserOperation, getEmptyUserOperation } from "test/utils/UserOperation.sol";
import { signHash } from "test/utils/Signature.sol";
import { EIP1271_MAGIC_VALUE } from "test/utils/Constants.sol";

contract OwnableValidatorTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    OwnableValidator internal validator;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 _threshold = 2;
    address[] _owners;
    uint256[] _ownerPks;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();
        validator = new OwnableValidator();

        _owners = new address[](2);
        _ownerPks = new uint256[](2);

        (address _owner1, uint256 _owner1Pk) = makeAddrAndKey("owner1");
        _owners[0] = _owner1;
        _ownerPks[0] = _owner1Pk;

        (address _owner2, uint256 _owner2Pk) = makeAddrAndKey("owner2");
        _owners[1] = _owner2;
        _ownerPks[1] = _owner2Pk;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        bytes memory data = abi.encode(_threshold, _owners);

        validator.onInstall(data);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.AlreadyInitialized.selector, address(this))
        );
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_ThresholdIs0() public whenModuleIsNotIntialized {
        // it should revert
        bytes memory data = abi.encode(0, _owners);

        vm.expectRevert(abi.encodeWithSelector(OwnableValidator.ThresholdNotSet.selector));
        validator.onInstall(data);
    }

    function test_OnInstallWhenThresholdIsNot0()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
    {
        // it should set the threshold
        bytes memory data = abi.encode(_threshold, _owners);

        validator.onInstall(data);

        uint256 threshold = validator.threshold(address(this));
        assertEq(threshold, _threshold);
    }

    function test_OnInstallRevertWhen_OwnersLengthIsLessThanThreshold()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
    {
        // it should revert
        bytes memory data = abi.encode(3, _owners);

        vm.expectRevert(abi.encodeWithSelector(OwnableValidator.InvalidThreshold.selector));
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_OwnersInclude0Address()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenOwnersLengthIsNotLessThanThreshold
    {
        // it should revert
        address[] memory _newOwners = new address[](2);
        _newOwners[0] = address(0);
        _newOwners[1] = _owners[1];
        bytes memory data = abi.encode(_threshold, _newOwners);

        vm.expectRevert(abi.encodeWithSelector(OwnableValidator.InvalidOwner.selector, address(0)));
        validator.onInstall(data);
    }

    function test_OnInstallWhenOwnersIncludeDuplicates()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenOwnersLengthIsNotLessThanThreshold
    {
        // it should set only unique owners
        address[] memory _newOwners = new address[](3);
        _newOwners[0] = _owners[0];
        _newOwners[1] = _owners[1];
        _newOwners[2] = _owners[0];
        bytes memory data = abi.encode(_threshold, _newOwners);

        validator.onInstall(data);

        address[] memory owners = validator.getOwners(address(this));
        assertEq(owners.length, 2);
    }

    function test_OnInstallWhenOwnersIncludeNoDuplicates()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenOwnersLengthIsNotLessThanThreshold
    {
        // it should set all owners
        bytes memory data = abi.encode(_threshold, _owners);

        validator.onInstall(data);

        address[] memory owners = validator.getOwners(address(this));
        assertEq(owners.length, _owners.length);
    }

    function test_OnUninstallShouldRemoveAllOwners() public {
        // it should remove all owners
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        validator.onUninstall("");

        address[] memory owners = validator.getOwners(address(this));
        assertEq(owners.length, 0);
    }

    function test_OnUninstallShouldSetThresholdTo0() public {
        // it should set threshold to 0
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        validator.onUninstall("");

        uint256 threshold = validator.threshold(address(this));
        assertEq(threshold, 0);
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool isInitialized = validator.isInitialized(address(this));
        assertFalse(isInitialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        bool isInitialized = validator.isInitialized(address(this));
        assertTrue(isInitialized);
    }

    function test_SetThresholdRevertWhen_ModuleIsNotIntialized() external {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        validator.setThreshold(1);
    }

    function test_SetThresholdRevertWhen_ThresholdIs0() external whenModuleIsIntialized {
        // it should revert
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        vm.expectRevert(OwnableValidator.InvalidThreshold.selector);
        validator.setThreshold(0);
    }

    function test_SetThresholdRevertWhen_ThresholdIsHigherThanOwnersLength()
        external
        whenModuleIsIntialized
        whenThresholdIsNot0
    {
        // it should revert
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        vm.expectRevert(OwnableValidator.InvalidThreshold.selector);
        validator.setThreshold(10);
    }

    function test_SetThresholdWhenThresholdIsNotHigherThanOwnersLength()
        external
        whenModuleIsIntialized
        whenThresholdIsNot0
    {
        // it should set the threshold
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        uint256 oldThreshold = validator.threshold(address(this));
        uint256 newThreshold = 1;
        assertNotEq(oldThreshold, newThreshold);

        validator.setThreshold(newThreshold);

        assertEq(validator.threshold(address(this)), newThreshold);
    }

    function test_AddOwnerRevertWhen_ModuleIsNotIntialized() external {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        validator.addOwner(address(1));
    }

    function test_AddOwnerRevertWhen_OwnerIs0Address() external whenModuleIsIntialized {
        // it should revert
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        address newOwner = address(0);
        vm.expectRevert(abi.encodeWithSelector(OwnableValidator.InvalidOwner.selector, newOwner));
        validator.addOwner(newOwner);
    }

    function test_AddOwnerRevertWhen_OwnerIsAlreadyAdded() external whenModuleIsIntialized {
        // it should revert
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        vm.expectRevert(abi.encodeWithSelector(OwnableValidator.InvalidOwner.selector, _owners[0]));
        validator.addOwner(_owners[0]);
    }

    function test_AddOwnerWhenOwnerIsNotAdded() external whenModuleIsIntialized {
        // it should add the owner
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        address newOwner = address(2);
        validator.addOwner(newOwner);

        address[] memory owners = validator.getOwners(address(this));
        assertEq(owners.length, 3);
        assertEq(owners[0], newOwner);
    }

    function test_RemoveOwnerRevertWhen_ModuleIsNotIntialized() external {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        validator.removeOwner(_owners[1], _owners[0]);
    }

    function test_RemoveOwnerWhenModuleIsIntialized() external {
        // it should remove the owner
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        validator.removeOwner(_owners[0], _owners[1]);
    }

    function test_GetOwnersShouldGetAllOwners() external {
        // it should get all owners
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        address[] memory owners = validator.getOwners(address(this));
        assertEq(owners.length, _owners.length);
        assertEq(owners[0], _owners[0]);
        assertEq(owners[1], _owners[1]);
    }

    function test_ValidateUserOpWhenThresholdIsNotSet() public {
        // it should return 1
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenTheSignaturesAreNotValid() public whenThresholdIsSet {
        // it should return 1
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(uint256(1), userOpHash);
        bytes memory signature2 = signHash(uint256(2), userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenTheUniqueSignaturesAreLessThanThreshold()
        public
        whenThresholdIsSet
        whenTheSignaturesAreValid
    {
        // it should return 1
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_ownerPks[0], userOpHash);
        bytes memory signature2 = signHash(uint256(2), userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenTheUniqueSignaturesAreGreaterThanThreshold()
        public
        whenThresholdIsSet
        whenTheSignaturesAreValid
    {
        // it should return 0
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_ownerPks[0], userOpHash);
        bytes memory signature2 = signHash(_ownerPks[1], userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 0);
    }

    function test_IsValidSignatureWithSenderWhenThresholdIsNotSet() public {
        // it should revert
        address sender = address(1);
        bytes32 hash = bytes32(keccak256("hash"));
        bytes memory data = "";

        vm.expectRevert(abi.encodeWithSelector(OwnableValidator.ThresholdNotSet.selector));
        bytes4 result = validator.isValidSignatureWithSender(sender, hash, data);
    }

    function test_IsValidSignatureWithSenderWhenTheSignaturesAreNotValid()
        public
        whenThresholdIsSet
    {
        // it should return EIP1271_FAILED
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        address sender = address(1);
        bytes32 hash = bytes32(keccak256("hash"));

        bytes memory signature1 = signHash(uint256(1), hash);
        bytes memory signature2 = signHash(uint256(2), hash);
        bytes memory data = abi.encodePacked(signature1, signature2);

        bytes4 result = validator.isValidSignatureWithSender(sender, hash, data);
        assertNotEq(result, EIP1271_MAGIC_VALUE);
    }

    function test_IsValidSignatureWithSenderWhenTheUniqueSignaturesAreLessThanThreshold()
        public
        whenThresholdIsSet
        whenTheSignaturesAreValid
    {
        // it should return EIP1271_FAILED
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        address sender = address(1);
        bytes32 hash = bytes32(keccak256("hash"));

        bytes memory signature1 = signHash(_ownerPks[0], hash);
        bytes memory signature2 = signHash(uint256(2), hash);
        bytes memory data = abi.encodePacked(signature1, signature2);

        bytes4 result = validator.isValidSignatureWithSender(sender, hash, data);
        assertNotEq(result, EIP1271_MAGIC_VALUE);
    }

    function test_IsValidSignatureWithSenderWhenTheUniqueSignaturesAreGreaterThanThreshold()
        public
        whenThresholdIsSet
        whenTheSignaturesAreValid
    {
        // it should return ERC1271_MAGIC_VALUE
        test_OnInstallWhenOwnersIncludeNoDuplicates();

        address sender = address(1);
        bytes32 hash = bytes32(keccak256("hash"));

        bytes memory signature1 = signHash(_ownerPks[0], hash);
        bytes memory signature2 = signHash(_ownerPks[1], hash);
        bytes memory data = abi.encodePacked(signature1, signature2);

        bytes4 result = validator.isValidSignatureWithSender(sender, hash, data);
        assertEq(result, EIP1271_MAGIC_VALUE);
    }

    function test_Name() public {
        // it should return OwnableValidator
        string memory name = validator.name();
        assertEq(name, "OwnableValidator");
    }

    function test_Version() public {
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

    modifier whenModuleIsIntialized() {
        _;
    }

    modifier whenThresholdIsNot0() {
        _;
    }

    modifier whenOwnersLengthIsNotLessThanThreshold() {
        _;
    }

    modifier whenThresholdIsSet() {
        _;
    }

    modifier whenTheSignaturesAreValid() {
        _;
    }
}
