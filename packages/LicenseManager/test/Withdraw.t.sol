// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LicenseManager.t.sol";
import "src/operator/SwapOperator.sol";
import "src/DataTypes.sol";

contract WithdrawTest is LicenseManagerTest {
    using CurrencyLibrary for Currency;

    SwapOperator operator;

    function setUp() public override {
        super.setUp();
        operator = new SwapOperator(licenseManager, SWAPROUTER);
        vm.prank(beneficiary1);
        licenseManager.setOperator(address(operator), true);
    }

    function test_operatorWithdraw() public {
        test_claim_transaction();

        uint256 balance =
            licenseManager.balanceOf(beneficiary1, Currency.wrap(address(weth)).toId());
        SwapOperator.OwnerAndBalance[] memory withdraws = new SwapOperator.OwnerAndBalance[](1);

        withdraws[0] = SwapOperator.OwnerAndBalance({ account: beneficiary1, amount: balance });

        uint24 poolFee = 3000;

        bytes memory path = abi.encodePacked(weth, poolFee, usdc);
        vm.prank(operator.entryPoint());
        operator.swap({
            withdraws: withdraws,
            path: path,
            gasRefund: ISwapRouter.ExactOutputSingleParams({
                tokenIn: address(weth),
                tokenOut: address(usdc),
                fee: 3000,
                recipient: address(operator),
                deadline: block.timestamp + 1000,
                amountOut: 10_000,
                amountInMaximum: 10_000 ether,
                sqrtPriceLimitX96: uint160(0)
            })
        });
    }
}
