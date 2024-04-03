// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Base.t.sol";

contract TransactionFeeTest is BaseTest {
    function test_TxFee_swap() public {
        vm.startPrank(module.addr);

        licenseMgr.permitClaim(
            instance.account,
            address(0),
            Claim({
                claimType: ClaimType.Transaction,
                module: module.addr,
                smartAccount: instance.account,
                payToken: IERC20(address(weth)),
                usdAmount: 100_000,
                data: ""
            })
        );

        vm.stopPrank();
    }

    function test_TxFee() public {
        vm.startPrank(module.addr);

        licenseMgr.permitClaim(
            instance.account,
            address(0),
            Claim({
                claimType: ClaimType.Transaction,
                module: module.addr,
                smartAccount: instance.account,
                payToken: IERC20(address(usdc)),
                usdAmount: 100_000,
                data: ""
            })
        );

        vm.stopPrank();
    }
}
