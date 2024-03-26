// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Base.t.sol";
import "forge-std/console2.sol";

contract SubscriptionTest is BaseTest {
    function setUp() public override {
        super.setUp();

        licenseMgr.setSubscriptionConfig({
            module: module.addr,
            pricePerSecond: uint128(10),
            minSubTime: uint128(1 * 7 days)
        });
    }

    function test_sub() public {
        SubscriptionClaim memory claim = SubscriptionClaim({
            module: module.addr,
            smartAccount: instance.account,
            token: IERC20(address(token)),
            amount: 100e18,
            data: ""
        });
        vm.prank(instance.account);
        licenseMgr.subscriptionRenewal(module.addr, claim);

        bool valid = licenseMgr.checkLicense(instance.account, module.addr);
        uint48 validUntil = licenseMgr.checkLicenseUntil(instance.account, module.addr);
        assertTrue(block.timestamp < validUntil);
        assertTrue(valid, "License is not valid");
    }
}
