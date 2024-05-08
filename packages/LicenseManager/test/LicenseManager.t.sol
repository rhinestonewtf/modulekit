// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/LicenseManager.sol";
import "src/DataTypes.sol";
import "src/subscription/Subscription.sol";
import "./mocks/MockProtocolController.sol";
import "./mocks/MockModule.sol";
import "./mocks/MockOperator.sol";
import "./mocks/MockFeeMachine.sol";
import "./Fork.t.sol";
import { MockERC20 } from "forge-std/mocks/MockERC20.sol";

contract LicenseManagerTest is ForkTest {
    using CurrencyLibrary for Currency;

    LicenseManager licenseManager;

    SubscriptionToken subtoken;

    MockProtocolController protocolController;
    MockModule module;
    MockFeeMachine feeMachine;
    MockOperator mockOperator;

    address account;

    address developer;

    address beneficiary1 = makeAddr("beneficiary1");
    address beneficiary2 = makeAddr("beneficiary2");

    function setUp() public virtual override {
        super.setUp();
        account = makeAddr("account");
        developer = makeAddr("developer");
        protocolController = new MockProtocolController();
        subtoken = new SubscriptionToken();
        licenseManager = new LicenseManager(protocolController, ISubscription(address(subtoken)));
        subtoken.authorizeMintAuthority(address(licenseManager));
        feeMachine = new MockFeeMachine();
        module = new MockModule(licenseManager);
        mockOperator = new MockOperator(licenseManager);

        deal(address(weth), account, 1_000_000_000 ether);

        deal(address(usdc), account, 1_000_000_000 ether);

        // authorize module
        vm.prank(address(protocolController));
        licenseManager.authorizeFeeMachine(feeMachine, true);

        vm.prank(address(feeMachine));
        licenseManager.setModule(address(module), developer, true);

        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 0.1 ether;
        feeMachine.setSplit(beneficiaries, amounts);

        vm.startPrank(account);

        IERC20(usdc).approve(address(licenseManager), 100_000_000 ether);
        IERC20(weth).approve(address(licenseManager), 100_000_000 ether);

        vm.stopPrank();

        vm.prank(beneficiary1);
        licenseManager.setOperator(address(mockOperator), true);

        uint128 secondsPerDay = 86_400;
        uint128 secPerYear = secondsPerDay * 365;
        uint128 pricePerYear = 10 ether;

        uint128 pricePerSecond = pricePerYear / secPerYear;
        vm.prank(developer);
        licenseManager.setSubscription(
            address(module),
            PricingSubscription({
                currency: Currency.wrap(address(usdc)),
                pricePerSecond: pricePerSecond,
                minSubTime: 1 days
            })
        );
    }

    function test_claim_transaction() public {
        console2.log("balance", IERC20(weth).balanceOf(account));
        ClaimTransaction memory claim = ClaimTransaction({
            account: account,
            currency: Currency.wrap(address(weth)),
            amount: 100 ether,
            feeMachineData: "",
            referral: address(0)
        });
        module.triggerClaim({ claim: claim });
    }

    function test_claim_subscription() public {
        uint256 validUntil = subtoken.subscriptionOf({ module: address(module), account: account });
        assertTrue(validUntil == 0);
        uint256 balanceBefore = IERC20(usdc).balanceOf(account);
        ClaimSubscription memory claim = ClaimSubscription({
            account: account,
            module: address(module),
            amount: 1 ether,
            feeMachineData: "",
            referral: address(0)
        });

        vm.prank(account);
        licenseManager.settleSubscription(claim);

        uint256 balanceAfter = IERC20(usdc).balanceOf(account);

        assertTrue(balanceAfter < balanceBefore);
        validUntil = subtoken.subscriptionOf({ module: address(module), account: account });
        assertTrue(validUntil > 0);
    }
}
