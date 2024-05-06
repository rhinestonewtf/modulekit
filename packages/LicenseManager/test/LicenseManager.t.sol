// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/LicenseManager.sol";
import "src/DataTypes.sol";
import "./mocks/MockProtocolController.sol";
import "./mocks/MockModule.sol";
import "./mocks/MockOperator.sol";
import "./mocks/MockFeeMachine.sol";
import { MockERC20 } from "forge-std/mocks/MockERC20.sol";

contract LicenseManagerTest is Test {
    using CurrencyLibrary for Currency;

    LicenseManager licenseManager;

    MockProtocolController protocolController;
    MockModule module;
    MockFeeMachine feeMachine;
    MockOperator operator;
    MockERC20 token1;
    MockERC20 token2;

    address account;

    address developer;

    address beneficiary1 = makeAddr("beneficiary1");
    address beneficiary2 = makeAddr("beneficiary2");

    function setUp() public {
        account = makeAddr("account");
        developer = makeAddr("developer");
        protocolController = new MockProtocolController();
        licenseManager = new LicenseManager(protocolController);
        feeMachine = new MockFeeMachine();
        token1 = new MockERC20();
        token2 = new MockERC20();
        module = new MockModule(licenseManager);
        operator = new MockOperator(licenseManager);

        token1.initialize("USDC", "USDC", 18);
        vm.label(address(token1), "USDC");
        deal(address(token1), account, 10_000 ether);

        token2.initialize("WETH", "WETH", 18);
        vm.label(address(token2), "WETH");
        deal(address(token2), account, 10_000 ether);

        // authorize module
        vm.prank(address(protocolController));
        licenseManager.setFeeMachine(feeMachine, true);

        vm.prank(address(feeMachine));
        licenseManager.setModule(address(module), developer, true);

        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 0.1 ether;
        feeMachine.setSplit(beneficiaries, amounts);

        // vm.startPrank(account);
        //
        // token1.approve(address(licenseManager), 10_000 ether);
        // token2.approve(address(licenseManager), 10_000 ether);
        //
        // vm.stopPrank();

        vm.prank(beneficiary1);
        licenseManager.setOperator(address(operator), true);

        uint128 secondsPerDay = 86_400;
        uint128 secPerYear = secondsPerDay * 365;
        uint128 pricePerYear = 10 ether;

        uint128 pricePerSecond = pricePerYear / secPerYear;
        licenseManager.setSubscriptionConfig(
            address(module), Currency.wrap(address(token1)), pricePerSecond, 1 days
        );
    }

    function test_claim_transaction() public {
        ClaimTransaction memory claim = ClaimTransaction({
            account: account,
            currency: Currency.wrap(address(token1)),
            amount: 100 ether,
            feeMachineData: "",
            referral: address(0)
        });
        module.triggerClaim({ claim: claim });
    }

    function test_claim_subscription() public {
        uint48 validUntil = licenseManager.getSubscriptionValidUntil(account, address(module));
        assertTrue(validUntil == 0);
        uint256 balanceBefore = token1.balanceOf(account);
        ClaimSubscription memory claim = ClaimSubscription({
            account: account,
            module: address(module),
            amount: 1 ether,
            feeMachineData: "",
            referral: address(0)
        });

        vm.prank(account);
        licenseManager.settleSubscription(claim);

        uint256 balanceAfter = token1.balanceOf(account);

        assertTrue(balanceAfter < balanceBefore);
        validUntil = licenseManager.getSubscriptionValidUntil(account, address(module));
        assertTrue(validUntil > 0);
    }

    function test_simulateSwap() public {
        test_claim_transaction();

        uint256 balance =
            licenseManager.balanceOf(beneficiary1, Currency.wrap(address(token1)).toId());

        operator.simulateSwap(beneficiary1, Currency.wrap(address(token1)), balance);

        uint256 balanceToken = token1.balanceOf(address(operator));

        assertEq(balanceToken, balance);
    }
}
