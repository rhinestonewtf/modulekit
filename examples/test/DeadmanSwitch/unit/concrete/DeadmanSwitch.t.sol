// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/Base.t.sol";
import { DeadmanSwitch, ERC7579ValidatorBase } from "src/DeadmanSwitch/DeadmanSwitch.sol";
import { IERC7579Module } from "modulekit/src/external/ERC7579.sol";
import {
    PackedUserOperation,
    getEmptyUserOperation,
    parseValidationData,
    ValidationData
} from "test/utils/ERC4337.sol";
import { signHash } from "test/utils/Signature.sol";

contract DeadmanSwitchTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    DeadmanSwitch internal dms;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address _nominee;
    uint256 _nomineePk;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseTest.setUp();
        dms = new DeadmanSwitch();

        (_nominee, _nomineePk) = makeAddrAndKey("nominee");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallWhenInitdataProvided() external whenModuleIsIntialized {
        // it should return
        uint48 timeout = uint48(1);
        bytes memory data = abi.encodePacked(_nominee, timeout);

        dms.onInstall(data);
        dms.onInstall("");
    }

    function test_OnInstallRevertWhen_InitdataNotProvided() external whenModuleIsIntialized {
        // it should revert
        uint48 timeout = uint48(1);
        bytes memory data = abi.encodePacked(_nominee, timeout);

        dms.onInstall(data);

        vm.expectRevert(
            abi.encodeWithSelector(IERC7579Module.AlreadyInitialized.selector, address(this))
        );
        dms.onInstall(data);
    }

    function test_OnInstallWhenModuleIsNotIntialized() public {
        // it should set the config args to the provided data
        // it should set the lastAccess to the current block timestamp
        uint48 _timeout = uint48(1);
        bytes memory data = abi.encodePacked(_nominee, _timeout);

        dms.onInstall(data);

        (uint48 lastAccess, uint48 timeout, address nominee) = dms.config(address(this));

        assertEq(lastAccess, block.timestamp);
        assertEq(nominee, _nominee);
        assertEq(timeout, _timeout);
    }

    function test_OnUninstallShouldDeleteTheConfig() public {
        // it should delete the config
        test_OnInstallWhenModuleIsNotIntialized();

        dms.onUninstall("");

        (uint48 lastAccess, uint48 timeout, address nominee) = dms.config(address(this));

        assertEq(lastAccess, uint48(0));
        assertEq(nominee, address(0));
        assertEq(timeout, uint48(0));
    }

    function test_IsInitializedWhenModuleIsNotIntialized() public {
        // it should return false
        bool isInitialized = dms.isInitialized(address(this));
        assertFalse(isInitialized);
    }

    function test_IsInitializedWhenModuleIsIntialized() public {
        // it should return true
        test_OnInstallWhenModuleIsNotIntialized();

        bool isInitialized = dms.isInitialized(address(this));
        assertTrue(isInitialized);
    }

    function test_PreCheckWhenModuleIsNotIntialized() public {
        // it should not update the lastAccess
        // it should return
        address msgSender = address(0);
        uint256 msgValue = 0;
        bytes memory msgData = "";

        dms.preCheck(msgSender, msgValue, msgData);

        (uint48 lastAccess,,) = dms.config(address(this));
        assertEq(lastAccess, 0);
    }

    function test_PreCheckWhenModuleIsIntialized() public {
        // it set the lastAccess to the current block timestamp
        test_OnInstallWhenModuleIsNotIntialized();

        address msgSender = address(0);
        uint256 msgValue = 0;
        bytes memory msgData = "";

        dms.preCheck(msgSender, msgValue, msgData);

        (uint48 lastAccess,,) = dms.config(address(this));
        assertEq(lastAccess, uint48(block.timestamp));
    }

    function test_PostCheckShouldReturn() public {
        // it should return
        dms.postCheck("");
    }

    function test_ValidateUserOpWhenModuleIsNotIntialized() public {
        // it should return 1
        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = bytes32(0);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(dms.validateUserOp(userOp, userOpHash));
        assertEq(validationData, 1);
    }

    function test_ValidateUserOpWhenSignatureIsInvalid() public whenModuleIsIntialized {
        // it should return invalid sig
        test_OnInstallWhenModuleIsNotIntialized();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = keccak256("userOpHash");

        userOp.signature = signHash(uint256(1), userOpHash);

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(dms.validateUserOp(userOp, userOpHash));
        ValidationData memory data = parseValidationData(validationData);

        assertEq(data.aggregator, address(1));
    }

    function test_ValidateUserOpWhenSignatureIsValid() public whenModuleIsIntialized {
        // it should return valid sig and valid after
        test_OnInstallWhenModuleIsNotIntialized();

        PackedUserOperation memory userOp = getEmptyUserOperation();
        userOp.sender = address(this);
        bytes32 userOpHash = keccak256("userOpHash");

        userOp.signature = signHash(_nomineePk, userOpHash);

        (uint48 lastAccess, uint48 timeout, address nominee) = dms.config(address(this));

        uint256 validationData =
            ERC7579ValidatorBase.ValidationData.unwrap(dms.validateUserOp(userOp, userOpHash));
        ValidationData memory data = parseValidationData(validationData);

        assertEq(data.aggregator, address(0));
        assertEq(lastAccess + timeout, data.validAfter);
        assertEq(type(uint48).max, data.validUntil);
    }

    function test_IsValidSignatureWithSenderShouldRevert() public {
        // it should revert
        address sender = address(1);
        bytes32 hash = bytes32(keccak256("hash"));
        bytes memory signature = "";

        vm.expectRevert(DeadmanSwitch.UnsopportedOperation.selector);
        dms.isValidSignatureWithSender(sender, hash, signature);
    }

    function test_NameShouldReturnDeadmanSwitch() public {
        // it should return DeadmanSwitch
        string memory name = dms.name();
        assertEq(name, "DeadmanSwitch");
    }

    function test_VersionShouldReturn100() public {
        // it should return 1.0.0
        string memory version = dms.version();
        assertEq(version, "1.0.0");
    }

    function test_IsModuleTypeWhenTypeIDIs1() public {
        // it should return true
        bool isModuleType = dms.isModuleType(1);
        assertTrue(isModuleType);
    }

    function test_IsModuleTypeWhenTypeIDIs4() public {
        // it should return true
        bool isModuleType = dms.isModuleType(4);
        assertTrue(isModuleType);
    }

    function test_IsModuleTypeWhenTypeIDIsNot1Or4() public {
        // it should return false
        bool isModuleType = dms.isModuleType(2);
        assertFalse(isModuleType);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenModuleIsIntialized() {
        _;
    }

    modifier whenSignatureIsValid() {
        _;
    }
}
