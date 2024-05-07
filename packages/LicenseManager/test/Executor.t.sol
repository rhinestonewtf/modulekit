// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LicenseManager.t.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";

contract ExecutorTest is LicenseManager, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;

    function setUp() public override {
        super.setUp();

        instance = makeAccount("instance");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(autosavings),
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
