// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LicenseManager.t.sol";
import "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "erc7579/interfaces/IERC7579Module.sol";

contract ExecutorTest is LicenseManagerTest, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;

    function setUp() public override {
        super.setUp();

        instance = makeAccountInstance("instance");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(licenseManager),
            data: abi.encode(true, new address[](0))
        });
    }

    function test_foo() public {
        ClaimTransaction memory claim = ClaimTransaction({
            account: instance.account,
            currency: Currency.wrap(address(weth)),
            amount: 100 ether,
            feeMachineData: "",
            referral: address(0)
        });
        module.triggerClaim({ claim: claim });
    }
}
