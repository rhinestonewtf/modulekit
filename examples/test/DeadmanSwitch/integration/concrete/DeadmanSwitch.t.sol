// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    BaseIntegrationTest,
    ModuleKitHelpers,
    ModuleKitSCM,
    ModuleKitUserOp
} from "test/BaseIntegration.t.sol";
import { DeadmanSwitch } from "src/DeadmanSwitch/DeadmanSwitch.sol";
import {
    PackedUserOperation,
    getEmptyUserOperation,
    parseValidationData,
    ValidationData
} from "test/utils/ERC4337.sol";
import { signHash } from "test/utils/Signature.sol";
import { MODULE_TYPE_HOOK, MODULE_TYPE_VALIDATOR } from "modulekit/src/external/ERC7579.sol";
import { UserOpData } from "modulekit/src/ModuleKit.sol";

contract DeadmanSwitchIntegrationTest is BaseIntegrationTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    DeadmanSwitch internal dms;

    /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    address _nominee;
    uint256 _nomineePk;
    uint48 _timeout;

    /*//////////////////////////////////////////////////////////////////////////
                                      SETUP
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        BaseIntegrationTest.setUp();
        dms = new DeadmanSwitch();

        (_nominee, _nomineePk) = makeAddrAndKey("nominee");
        _timeout = uint48(block.timestamp + 100 days);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(dms),
            data: abi.encodePacked(_nominee, _timeout)
        });

        instance.installModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(dms), data: "" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      TESTS
    //////////////////////////////////////////////////////////////////////////*/

    function test_OnInstallSetsNomineeAndTimeout() public {
        // it should set timeout and nominee
        (uint48 lastAccess, uint48 timeout, address nominee) = dms.config(address(instance.account));

        assertEq(lastAccess, block.timestamp);
        assertEq(nominee, _nominee);
        assertEq(timeout, _timeout);
    }

    function test_onUninstallRemovesConfig() public {
        // it should remove the config
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(dms),
            data: ""
        });
        instance.uninstallModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(dms), data: "" });

        (uint48 lastAccess, uint48 timeout, address nominee) = dms.config(address(instance.account));

        assertEq(lastAccess, 0);
        assertEq(nominee, address(0));
        assertEq(timeout, 0);
    }

    function test_TransactionIncreasesLastAccess() public {
        // it should increase the lastAccess
        uint256 difference = 10 days;
        vm.warp(block.timestamp + difference);

        (uint48 lastAccess,,) = dms.config(address(instance.account));

        instance.getExecOps({
            target: address(1),
            value: 1,
            callData: "",
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        (uint48 newLastAccess,,) = dms.config(address(instance.account));

        assertEq(newLastAccess, lastAccess + difference);
    }

    function test_ValidateUserOp_RevertWhen_TimeoutNotDue() public {
        // it should revert
        UserOpData memory userOpData = instance.getExecOps({
            target: address(1),
            value: 1,
            callData: "",
            txValidator: address(dms)
        });
        userOpData.userOp.signature = signHash(_nomineePk, userOpData.userOpHash);

        instance.expect4337Revert();
        userOpData.execUserOps();
    }

    function test_ValidateUserOp() public {
        // it should revert
        vm.warp(block.timestamp + _timeout);

        address target = makeAddr("target");

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: 1,
            callData: "",
            txValidator: address(dms)
        });
        userOpData.userOp.signature = signHash(_nomineePk, userOpData.userOpHash);
        userOpData.execUserOps();

        assertEq(target.balance, 1);
    }
}
