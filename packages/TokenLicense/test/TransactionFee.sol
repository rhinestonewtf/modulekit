// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Base.t.sol";

contract TransactionFeeTest is BaseTest {
    function test_claimTransactionFees() public {
        vm.startPrank(module.addr);

        TransactionClaim memory claim = TransactionClaim({
            module: module.addr,
            smartAccount: instance.account,
            token: IERC20(address(token)),
            amount: 100e18,
            data: ""
        });
        licenseMgr.claimTxFee(claim);

        vm.stopPrank();
    }
}
