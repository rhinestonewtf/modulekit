// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "./utils/safe-base/AccountFactory.sol";
import "./utils/safe-base/RhinestoneUtil.sol";

/// @title ExampleTestSafeBase
/// @author zeroknots

contract ExampleTestSafeBase is AccountFactory, Test {
    using RhinestoneUtil for AccountInstance;

    AccountInstance smartAccount;

    function setUp() public {
        super.init();
        smartAccount = newInstance();
    }

    function testSendEther() public {}
}
