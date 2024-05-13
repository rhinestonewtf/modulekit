// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp
} from "test/BaseIntegration.t.sol";
import { SocialRecovery, ERC7579ValidatorBase } from "src/SocialRecovery/SocialRecovery.sol";
import { IERC7579Module, IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { PackedUserOperation, getEmptyUserOperation } from "test/utils/ERC4337.sol";
import { signHash } from "test/utils/Signature.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib, Execution } from "erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/src/external/ERC7579.sol";
import { UserOpData } from "modulekit/src/ModuleKit.sol";
import { SENTINEL } from "sentinellist/SentinelList.sol";

contract SocialRecoveryIntegrationTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    SocialRecovery internal validator;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    uint256 _threshold = 2;
    address[] _guardians;
    uint256[] _guardianPks;
    uint256 _recoverCount;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseIntegrationTest.setUp();

        validator = new SocialRecovery();

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

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(_threshold, _guardians)
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallSetThresholdAndGuardians() public {
        // it should set threshold and guardians
        uint256 threshold = validator.threshold(address(instance.account));
        assertEq(threshold, _threshold);

        address[] memory guardians = validator.getGuardians(address(instance.account));
        assertEq(guardians.length, _guardians.length);

        uint256 guardianCount = validator.guardianCount(address(instance.account));
        assertEq(guardianCount, _guardians.length);
    }

    function test_OnUninstallRemoveThresholdAndGuardians() public {
        // it should remove the threshold and guardians
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });

        uint256 threshold = validator.threshold(address(instance.account));
        assertEq(threshold, 0);

        address[] memory guardians = validator.getGuardians(address(instance.account));
        assertEq(guardians.length, 0);

        uint256 guardianCount = validator.guardianCount(address(instance.account));
        assertEq(guardianCount, 0);
    }

    function test_SetThreshold() public {
        // it should set the threshold
        uint256 newThreshold = 1;

        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(SocialRecovery.setThreshold.selector, newThreshold),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        uint256 threshold = validator.threshold(address(instance.account));
        assertEq(threshold, newThreshold);
    }

    function test_AddGuardian() public {
        // it should add an guardian
        (address _guardian, uint256 _guardianPk) = makeAddrAndKey("guardian3");

        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(SocialRecovery.addGuardian.selector, _guardian),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory guardians = validator.getGuardians(address(instance.account));
        assertEq(guardians.length, _guardians.length + 1);

        uint256 guardianCount = validator.guardianCount(address(instance.account));
        assertEq(guardianCount, _guardians.length + 1);
    }

    function test_RemoveGuardian() public {
        // it should remove an guardian
        instance.getExecOps({
            target: address(validator),
            value: 0,
            callData: abi.encodeWithSelector(
                SocialRecovery.removeGuardian.selector, SENTINEL, _guardians[1]
            ),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        address[] memory guardians = validator.getGuardians(address(instance.account));
        assertEq(guardians.length, _guardians.length - 1);

        uint256 guardianCount = validator.guardianCount(address(instance.account));
        assertEq(guardianCount, _guardians.length - 1);
    }

    function test_ValidateUserOp() public {
        // it should validate the recovery user op
        address newValidator = address(this);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(newValidator),
            data: ""
        });

        UserOpData memory userOpData = instance.getExecOps({
            target: newValidator,
            value: 0,
            callData: abi.encodeWithSignature("recover()"),
            txValidator: address(validator)
        });
        bytes memory signature1 = signHash(_guardianPks[0], userOpData.userOpHash);
        bytes memory signature2 = signHash(_guardianPks[1], userOpData.userOpHash);
        userOpData.userOp.signature = abi.encodePacked(signature1, signature2);
        userOpData.execUserOps();

        assertEq(_recoverCount, 1);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALLBACKS
    //////////////////////////////////////////////////////////////////////////*/

    function isModuleType(uint256) external pure returns (bool) {
        return true;
    }

    function onInstall(bytes calldata) external { }

    function recover() external {
        _recoverCount++;
    }
}
