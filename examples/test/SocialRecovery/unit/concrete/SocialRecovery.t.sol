// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import { SocialRecovery, ERC7579ValidatorBase } from "src/SocialRecovery/SocialRecovery.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { PackedUserOperation, getEmptyUserOperation } from "test/utils/ERC4337.sol";
import { signHash } from "test/utils/Signature.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib, Execution } from "erc7579/lib/ExecutionLib.sol";
import { MockAccount } from "test/mocks/MockAccount.sol";
import { LibSort } from "solady/utils/LibSort.sol";

contract SocialRecoveryTest is BaseTest {
    using LibSort for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    SocialRecovery internal validator;
    MockAccount internal mockAccount;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 _threshold = 2;
    address[] _guardians;
    uint256[] _guardianPks;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();

        validator = new SocialRecovery();
        mockAccount = new MockAccount();

        _guardians = new address[](2);
        _guardianPks = new uint256[](2);

        (address _guardian1, uint256 _guardian1Pk) = makeAddrAndKey("guardian1");
        _guardians[0] = _guardian1;
        _guardianPks[0] = _guardian1Pk;

        (address _guardian2, uint256 _guardian2Pk) = makeAddrAndKey("guardian2");

        uint256 counter = 0;
        while (uint160(_guardian1) > uint160(_guardian2)) {
            counter++;
            (_guardian2, _guardian2Pk) = makeAddrAndKey(vm.toString(counter));
        }
        _guardians[1] = _guardian2;
        _guardianPks[1] = _guardian2Pk;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      UTILS
    //////////////////////////////////////////////////////////////////////////*/

    function installForAccount(address account) internal {
        bytes memory data = abi.encode(_threshold, _guardians);

        vm.prank(account);
        validator.onInstall(data);

        uint256 threshold = validator.threshold(account);
        assertEq(threshold, _threshold);

        address[] memory guardians = validator.getGuardians(account);
        assertEq(guardians.length, _guardians.length);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallRevertWhen_ModuleIsIntialized() public {
        // it should revert
        bytes memory data = abi.encode(_threshold, _guardians);

        validator.onInstall(data);

        vm.expectRevert();
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_ThresholdIs0() public whenModuleIsNotIntialized {
        // it should revert
        bytes memory data = abi.encode(0, _guardians);

        vm.expectRevert(abi.encodeWithSelector(SocialRecovery.ThresholdNotSet.selector));
        validator.onInstall(data);
    }

    function test_OnInstallWhenThresholdIsNot0()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
    {
        // it should set the threshold
        bytes memory data = abi.encode(_threshold, _guardians);

        validator.onInstall(data);

        uint256 threshold = validator.threshold(address(this));
        assertEq(threshold, _threshold);
    }

    function test_OnInstallRevertWhen_GuardiansLengthIsLessThanThreshold()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
    {
        // it should revert
        bytes memory data = abi.encode(3, _guardians);

        vm.expectRevert(abi.encodeWithSelector(SocialRecovery.InvalidThreshold.selector));
        validator.onInstall(data);
    }

    function test_OnInstallRevertWhen_GuardiansLengthIsMoreThanMax()
        external
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenGuardiansLengthIsNotLessThanThreshold
    {
        // it should revert
        address[] memory _newGuardians = new address[](33);
        for (uint256 i = 0; i < 33; i++) {
            _newGuardians[i] = makeAddr(vm.toString(i));
        }
        _newGuardians.sort();
        _newGuardians.uniquifySorted();

        bytes memory data = abi.encode(_threshold, _newGuardians);

        vm.expectRevert(abi.encodeWithSelector(SocialRecovery.MaxGuardiansReached.selector));
        validator.onInstall(data);
    }

    function test_OnInstallWhenGuardiansLengthIsNotMoreThanMax()
        external
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenGuardiansLengthIsNotLessThanThreshold
        whenGuardiansLengthIsNotMoreThanMax
    {
        // it should set guardian count
        bytes memory data = abi.encode(_threshold, _guardians);

        validator.onInstall(data);

        uint256 guardianCount = validator.guardianCount(address(this));
        assertEq(guardianCount, _guardians.length);
    }

    function test_OnInstallRevertWhen_GuardiansInclude0Address()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenGuardiansLengthIsNotLessThanThreshold
        whenGuardiansLengthIsNotMoreThanMax
    {
        // it should revert
        address[] memory _newGuardians = new address[](2);
        _newGuardians[0] = address(0);
        _newGuardians[1] = _guardians[1];
        bytes memory data = abi.encode(_threshold, _newGuardians);

        vm.expectRevert(abi.encodeWithSelector(SocialRecovery.InvalidGuardian.selector, address(0)));
        validator.onInstall(data);
    }

    function test_OnInstallWhenGuardiansIncludeDuplicates()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenGuardiansLengthIsNotLessThanThreshold
        whenGuardiansLengthIsNotMoreThanMax
    {
        // it should revert
        address[] memory _newGuardians = new address[](3);
        _newGuardians[0] = _guardians[0];
        _newGuardians[1] = _guardians[1];
        _newGuardians[2] = _guardians[0];
        bytes memory data = abi.encode(_threshold, _newGuardians);

        vm.expectRevert(abi.encodeWithSelector(SocialRecovery.NotSortedAndUnique.selector));
        validator.onInstall(data);
    }

    function test_OnInstallWhenGuardiansIncludeNoDuplicates()
        public
        whenModuleIsNotIntialized
        whenThresholdIsNot0
        whenGuardiansLengthIsNotLessThanThreshold
        whenGuardiansLengthIsNotMoreThanMax
    {
        // it should set all guardians
        bytes memory data = abi.encode(_threshold, _guardians);

        validator.onInstall(data);

        address[] memory guardians = validator.getGuardians(address(this));
        assertEq(guardians.length, _guardians.length);
    }

    function test_OnUninstallShouldRemoveTheThreshold() public {
        // it should remove the threshold
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        validator.onUninstall("");

        uint256 threshold = validator.threshold(address(this));
        assertEq(threshold, 0);
    }

    function test_OnUninstallShouldRemoveTheGuardians() public {
        // it should remove the guardians
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        validator.onUninstall("");

        address[] memory guardians = validator.getGuardians(address(this));
        assertEq(guardians.length, 0);
    }

    function test_OnUninstallShouldSetGuardianCountTo0() external {
        // it should set guardian count to 0
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        validator.onUninstall("");

        uint256 guardianCount = validator.guardianCount(address(this));
        assertEq(guardianCount, 0);
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool isInitialized = validator.isInitialized(address(this));
        assertFalse(isInitialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

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
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        vm.expectRevert(SocialRecovery.InvalidThreshold.selector);
        validator.setThreshold(0);
    }

    function test_SetThresholdRevertWhen_ThresholdIsHigherThanGuardiansLength()
        public
        whenModuleIsIntialized
        whenThresholdIsNot0
    {
        // it should revert
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        vm.expectRevert(SocialRecovery.InvalidThreshold.selector);
        validator.setThreshold(10);
    }

    function test_SetThresholdWhenThresholdIsNotHigherThanGuardiansLength()
        public
        whenModuleIsIntialized
        whenThresholdIsNot0
    {
        // it should set the threshold
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        uint256 oldThreshold = validator.threshold(address(this));
        uint256 newThreshold = 1;
        assertNotEq(oldThreshold, newThreshold);

        validator.setThreshold(newThreshold);

        assertEq(validator.threshold(address(this)), newThreshold);
    }

    function test_AddGuardianRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.NotInitialized.selector, address(this))
        );
        validator.addGuardian(address(1));
    }

    function test_AddGuardianRevertWhen_GuardianIs0Address() public whenModuleIsIntialized {
        // it should revert
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        address newGuardian = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(SocialRecovery.InvalidGuardian.selector, newGuardian)
        );
        validator.addGuardian(newGuardian);
    }

    function test_AddGuardianRevertWhen_GuardianCountIsMoreThanMax()
        external
        whenModuleIsIntialized
        whenGuardianIsNot0Address
    {
        // it should revert
        address[] memory _newGuardians = new address[](32);
        for (uint256 i = 0; i < 32; i++) {
            _newGuardians[i] = makeAddr(vm.toString(i));
        }
        _newGuardians.sort();
        _newGuardians.uniquifySorted();
        bytes memory data = abi.encode(_threshold, _newGuardians);

        validator.onInstall(data);

        vm.expectRevert(abi.encodeWithSelector(SocialRecovery.MaxGuardiansReached.selector));
        validator.addGuardian(makeAddr("finalGuardian"));
    }

    function test_AddGuardianRevertWhen_GuardianIsAlreadyAdded()
        public
        whenModuleIsIntialized
        whenGuardianIsNot0Address
        whenGuardianCountIsNotMoreThanMax
    {
        // it should revert
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        vm.expectRevert();
        validator.addGuardian(_guardians[0]);
    }

    function test_AddGuardianWhenGuardianIsNotAdded()
        public
        whenModuleIsIntialized
        whenGuardianIsNot0Address
        whenGuardianCountIsNotMoreThanMax
    {
        // it should increment guardian count
        // it should add the guardian
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        address newGuardian = address(2);
        validator.addGuardian(newGuardian);

        address[] memory guardians = validator.getGuardians(address(this));
        assertEq(guardians.length, 3);
        assertEq(guardians[0], newGuardian);

        uint256 guardianCount = validator.guardianCount(address(this));
        assertEq(guardianCount, 3);
    }

    function test_RemoveGuardianRevertWhen_ModuleIsNotIntialized() public {
        // it should revert
        vm.expectRevert();
        validator.removeGuardian(_guardians[1], _guardians[0]);
    }

    function test_RemoveGuardianWhenModuleIsIntialized() public {
        // it should decrement guardian count
        // it should remove the guardian
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        validator.removeGuardian(_guardians[1], _guardians[0]);

        address[] memory guardians = validator.getGuardians(address(this));
        assertEq(guardians.length, 1);

        uint256 guardianCount = validator.guardianCount(address(this));
        assertEq(guardianCount, 1);
    }

    function test_GetGuardiansShouldGetAllGuardians() external {
        // it should get all guardians
        test_OnInstallWhenGuardiansIncludeNoDuplicates();

        address[] memory guardians = validator.getGuardians(address(this));
        assertEq(guardians.length, _guardians.length);
        assertEq(guardians[0], _guardians[1]);
        assertEq(guardians[1], _guardians[0]);
    }

    function test_ValidateUserOpWhenThresholdIsNotSet() public {
        // it should return 1
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(mockAccount);
        userOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(1), 0, "")
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenTheSignaturesAreNotValid() public whenThresholdIsSet {
        // it should return 1
        installForAccount(address(mockAccount));

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(mockAccount);
        userOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(1), 0, "")
        );
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
        installForAccount(address(mockAccount));

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(mockAccount);
        userOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(1), 0, "")
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_guardianPks[0], userOpHash);
        bytes memory signature2 = signHash(uint256(2), userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenExecutionTypeIsNotCallTypeSingle()
        public
        whenThresholdIsSet
        whenTheSignaturesAreValid
        whenTheUniqueSignaturesAreGreaterThanThreshold
    {
        // it should return 1
        installForAccount(address(mockAccount));

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(mockAccount);
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution(address(1), 0, "");
        userOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            ModeLib.encodeSimpleBatch(),
            ExecutionLib.encodeBatch(executions)
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_guardianPks[0], userOpHash);
        bytes memory signature2 = signHash(_guardianPks[1], userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenExecutionTargetIsNotAnInstalledValidator()
        public
        whenThresholdIsSet
        whenTheSignaturesAreValid
        whenTheUniqueSignaturesAreGreaterThanThreshold
        whenExecutionTypeIsCallTypeSingle
    {
        // it should return 1
        installForAccount(address(mockAccount));

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(mockAccount);
        userOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(0x420), 0, "")
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_guardianPks[0], userOpHash);
        bytes memory signature2 = signHash(_guardianPks[1], userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenExecutionTargetIsAnInstalledValidator()
        public
        whenThresholdIsSet
        whenTheSignaturesAreValid
        whenTheUniqueSignaturesAreGreaterThanThreshold
        whenExecutionTypeIsCallTypeSingle
    {
        // it should return 0
        installForAccount(address(mockAccount));

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(mockAccount);
        userOp.callData = abi.encodeWithSelector(
            IERC7579Account.execute.selector,
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(address(1), 0, "")
        );
        bytes32 userOpHash = bytes32(keccak256("userOpHash"));

        bytes memory signature1 = signHash(_guardianPks[0], userOpHash);
        bytes memory signature2 = signHash(_guardianPks[1], userOpHash);
        userOp.signature = abi.encodePacked(signature1, signature2);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(validator.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 0);
    }

    function test_IsValidSignatureWithSenderShouldRevert() public {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(SocialRecovery.UnsopportedOperation.selector));
        validator.isValidSignatureWithSender(address(1), bytes32(keccak256("hash")), "");
    }

    function test_NameShouldReturnSocialRecoveryValidator() public {
        // it should return SocialRecoveryValidator
        string memory name = validator.name();
        assertEq(name, "SocialRecoveryValidator");
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

    modifier whenGuardiansLengthIsNotMoreThanMax() {
        _;
    }

    modifier whenGuardianCountIsNotMoreThanMax() {
        _;
    }

    modifier whenGuardianIsNot0Address() {
        _;
    }

    modifier whenGuardiansLengthIsNotLessThanThreshold() {
        _;
    }

    modifier whenModuleIsIntialized() {
        _;
    }

    modifier whenThresholdIsSet() {
        _;
    }

    modifier whenTheSignaturesAreValid() {
        _;
    }

    modifier whenTheUniqueSignaturesAreGreaterThanThreshold() {
        _;
    }

    modifier whenExecutionTypeIsCallTypeSingle() {
        _;
    }
}
