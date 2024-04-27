// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp
} from "test/BaseIntegration.t.sol";
import { OwnableValidator } from "src/OwnableValidator/OwnableValidator.sol";
import { signHash } from "test/utils/Signature.sol";
import { EIP1271_MAGIC_VALUE } from "test/utils/Constants.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/src/external/ERC7579.sol";
import { UserOpData } from "modulekit/src/ModuleKit.sol";
import { IERC1271 } from "modulekit/src/interfaces/IERC1271.sol";
import { SENTINEL } from "sentinellist/SentinelList.sol";

contract OwnableValidatorIntegrationTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

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
        BaseIntegrationTest.setUp();
        validator = new OwnableValidator();

        _owners = new address[](2);
        _ownerPks = new uint256[](2);

        (address _owner1, uint256 _owner1Pk) = makeAddrAndKey("owner1");
        _owners[0] = _owner1;
        _ownerPks[0] = _owner1Pk;

        (address _owner2, uint256 _owner2Pk) = makeAddrAndKey("owner2");

        uint256 counter = 0;
        while (uint160(_owner1) > uint160(_owner2)) {
            counter++;
            (_owner2, _owner2Pk) = makeAddrAndKey(vm.toString(counter));
        }
        _owners[1] = _owner2;
        _ownerPks[1] = _owner2Pk;

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(_threshold, _owners)
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallSetOwnersAndThreshold() public {
        // it should set the owners, threshold and ownercount
        uint256 threshold = validator.threshold(address(instance.account));
        assertEq(threshold, _threshold);

        address[] memory owners = validator.getOwners(address(instance.account));
        assertEq(owners.length, _owners.length);

        uint256 ownerCount = validator.ownerCount(address(instance.account));
        assertEq(ownerCount, _owners.length);
    }

    function test_OnUninstallRemovesOwnersAndThreshold() public {
        // it should remove the owners, threshold and ownercount
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });

        uint256 threshold = validator.threshold(address(instance.account));
        assertEq(threshold, 0);

        address[] memory owners = validator.getOwners(address(instance.account));
        assertEq(owners.length, 0);

        uint256 ownerCount = validator.ownerCount(address(instance.account));
        assertEq(ownerCount, 0);
    }

    function test_SetThreshold() public {
        // it should set the threshold
        uint256 newThreshold = 1;

        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(OwnableValidator.setThreshold.selector, newThreshold),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        uint256 threshold = validator.threshold(address(instance.account));
        assertEq(threshold, newThreshold);
    }

    function test_SetThreshold_RevertWhen_ThresholdTooHigh() public {
        // it should set the threshold
        uint256 newThreshold = 3;

        instance.expect4337Revert();
        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(OwnableValidator.setThreshold.selector, newThreshold),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();
    }

    function test_AddOwner() public {
        // it should add an owner
        // it should increment the owner count
        (address _owner, uint256 _ownerPk) = makeAddrAndKey("owner3");

        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(OwnableValidator.addOwner.selector, _owner),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory owners = validator.getOwners(address(instance.account));
        assertEq(owners.length, _owners.length + 1);

        uint256 ownerCount = validator.ownerCount(address(instance.account));
        assertEq(ownerCount, _owners.length + 1);
    }

    function test_RemoveOwner() public {
        // it should remove an owner
        // it should decrement the owner count
        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(
                OwnableValidator.removeOwner.selector, SENTINEL, _owners[1]
            ),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory owners = validator.getOwners(address(instance.account));
        assertEq(owners.length, _owners.length - 1);

        uint256 ownerCount = validator.ownerCount(address(instance.account));
        assertEq(ownerCount, _owners.length - 1);
    }

    function test_ValidateUserOp() public {
        // it should validate the user op
        address target = makeAddr("target");

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: 1,
            callData: "",
            txValidator: address(validator)
        });
        bytes memory signature1 = signHash(_ownerPks[0], userOpData.userOpHash);
        bytes memory signature2 = signHash(_ownerPks[1], userOpData.userOpHash);
        userOpData.userOp.signature = abi.encodePacked(signature1, signature2);
        userOpData.execUserOps();

        assertEq(target.balance, 1);
    }

    function test_ERC1271() public {
        // it should return the magic value
        address sender = address(1);
        bytes32 hash = bytes32(keccak256("hash"));

        bytes memory signature1 = signHash(_ownerPks[0], hash);
        bytes memory signature2 = signHash(_ownerPks[1], hash);
        bytes memory data = abi.encodePacked(signature1, signature2);

        bytes4 result = IERC1271(instance.account).isValidSignature(
            hash, abi.encodePacked(address(validator), data)
        );
        assertEq(result, EIP1271_MAGIC_VALUE);
    }
}
