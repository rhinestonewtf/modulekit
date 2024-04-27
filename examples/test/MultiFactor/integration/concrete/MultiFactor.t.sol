// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp
} from "test/BaseIntegration.t.sol";
import {
    MultiFactor,
    ERC7579ValidatorBase,
    Validator,
    ValidatorId
} from "src/MultiFactor/MultiFactor.sol";
import { OwnableValidator } from "src/OwnableValidator/OwnableValidator.sol";
import { signHash } from "test/utils/Signature.sol";
import { EIP1271_MAGIC_VALUE } from "test/utils/Constants.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/src/external/ERC7579.sol";
import { UserOpData } from "modulekit/src/ModuleKit.sol";
import { IERC1271 } from "modulekit/src/interfaces/IERC1271.sol";

contract MultiFactorIntegrationTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    MultiFactor internal validator;
    OwnableValidator internal subValidator1;
    OwnableValidator internal subValidator2;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint8 _threshold = 2;
    address[] _owners;
    uint256[] _ownerPks;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseIntegrationTest.setUp();

        validator = new MultiFactor(instance.aux.registry);

        subValidator1 = new OwnableValidator();
        subValidator2 = new OwnableValidator();

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

        Validator[] memory validators = _getValidators();

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encodePacked(_threshold, abi.encode(validators))
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getValidators() internal returns (Validator[] memory validators) {
        validators = new Validator[](2);
        validators[0] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(0), address(subValidator1))),
            data: abi.encode(_threshold, _owners)
        });
        validators[1] = Validator({
            packedValidatorAndId: bytes32(abi.encodePacked(uint96(0), address(subValidator2))),
            data: abi.encode(_threshold, _owners)
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallSetValidatorsAndThreshold() public {
        // it should set the validators and threshold
        (uint8 threshold, uint128 iteration) = validator.accountConfig(address(instance.account));
        assertEq(threshold, _threshold);

        bool isSubValidator1 = validator.isSubValidator(
            address(instance.account), address(subValidator1), ValidatorId.wrap(bytes12(0))
        );
        assertEq(isSubValidator1, true);

        bool isSubValidator2 = validator.isSubValidator(
            address(instance.account), address(subValidator2), ValidatorId.wrap(bytes12(0))
        );
        assertEq(isSubValidator2, true);
    }

    function test_OnUninstallRemovesOwnersAndThreshold() public {
        // it should remove the owners, threshold and ownercount
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });

        (uint8 threshold, uint128 iteration) = validator.accountConfig(address(instance.account));
        assertEq(iteration, 1);
        assertEq(threshold, uint8(0));
    }

    function test_SetThreshold() public {
        // it should set the threshold
        uint8 newThreshold = 1;

        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(MultiFactor.setThreshold.selector, newThreshold),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        (uint8 threshold,) = validator.accountConfig(address(instance.account));
        assertEq(threshold, newThreshold);
    }

    function test_SetThreshold_RevertWhen_ThresholdZero() public {
        // it should set the threshold
        uint8 newThreshold = 0;

        instance.expect4337Revert();
        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(MultiFactor.setThreshold.selector, newThreshold),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();
    }

    function test_SetValidator() public {
        // it should set the validator
        (address _owner, uint256 _ownerPk) = makeAddrAndKey("owner3");

        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(
                MultiFactor.setValidator.selector,
                address(subValidator1),
                ValidatorId.wrap(bytes12(uint96(1))),
                abi.encode(_threshold, _owners)
            ),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        bool isValidator = validator.isSubValidator(
            address(instance.account), address(subValidator1), ValidatorId.wrap(bytes12(uint96(1)))
        );
        assertTrue(isValidator);
    }

    function test_RemoveValidator() public {
        // it should remove a validator
        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(
                MultiFactor.removeValidator.selector,
                address(subValidator1),
                ValidatorId.wrap(bytes12(0))
            ),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        bool isValidator = validator.isSubValidator(
            address(instance.account), address(subValidator1), ValidatorId.wrap(bytes12(uint96(1)))
        );
        assertFalse(isValidator);
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
        Validator[] memory validators = _getValidators();

        bytes memory signature1 = signHash(_ownerPks[0], userOpData.userOpHash);
        bytes memory signature2 = signHash(_ownerPks[1], userOpData.userOpHash);
        bytes memory encodedSig = abi.encodePacked(signature1, signature2);

        validators[0].data = encodedSig;
        validators[1].data = encodedSig;

        userOpData.userOp.signature = abi.encode(validators);
        userOpData.execUserOps();

        assertEq(target.balance, 1);
    }

    function test_ERC1271() public {
        // it should return the magic value
        address sender = address(1);
        bytes32 hash = bytes32(keccak256("hash"));
        Validator[] memory validators = _getValidators();

        bytes memory signature1 = signHash(_ownerPks[0], hash);
        bytes memory signature2 = signHash(_ownerPks[1], hash);
        bytes memory encodedSig = abi.encodePacked(signature1, signature2);

        validators[0].data = encodedSig;
        validators[1].data = encodedSig;

        bytes4 result = IERC1271(instance.account).isValidSignature(
            hash, abi.encodePacked(address(validator), abi.encode(validators))
        );
        assertEq(result, EIP1271_MAGIC_VALUE);
    }
}
