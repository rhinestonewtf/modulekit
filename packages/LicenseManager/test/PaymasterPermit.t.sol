// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import "@rhinestone/modulekit/src/Mocks.sol";
import "@rhinestone/modulekit/src/Helpers.sol";
import "@rhinestone/modulekit/src/Core.sol";
import "src/LicensedValidator.sol";

import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "@rhinestone/modulekit/src/external/ERC7579.sol";

import { DeployPermit2 } from "permit2/test/utils/DeployPermit2.sol";
import { WETH } from "solady/src/tokens/WETH.sol";
import "src/PaymasterPermit.sol";

contract PaymasterPermitTest is RhinestoneModuleKit, DeployPermit2, Test {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    address permit2;
    PaymasterPermit paymaster;
    AccountInstance internal instance;

    Account internal receiver = makeAccount("receiver");
    LicensedValidator internal licensedValidator;
    MockERC20 internal token;

    WETH internal weth;

    function setUp() public {
        vm.warp(123_123_123);
        instance = makeAccountInstance("instance");
        vm.deal(instance.account, 100 ether);
        permit2 = deployPermit2();

        weth = new WETH();
        vm.label(address(weth), "WETH");

        paymaster = new PaymasterPermit(instance.aux.entrypoint, permit2, address(weth));

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);
        deal(address(weth), instance.account, 100 ether);

        licensedValidator = new LicensedValidator(receiver.addr, address(token));
        vm.label(address(licensedValidator), "LicensedValidator");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(licensedValidator),
            data: ""
        });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(paymaster),
            data: ""
        });

        deal(instance.account, 100 ether);
        deal(address(this), 100 ether);
        instance.aux.entrypoint.depositTo{ value: 1 ether }(address(paymaster));

        vm.prank(instance.account);
        token.approve(address(permit2), type(uint256).max);
        vm.prank(instance.account);
        weth.approve(address(permit2), type(uint256).max);

        paymaster.grantRoles(address(licensedValidator), PAID_VALIDATOR_ROLE);
        paymaster.setModuleDistribution(
            address(licensedValidator),
            IPaymasterPermit.Distribution({
                distributionMode: IPaymasterPermit.DistributionMode.NO_SWAP,
                receiver: receiver.addr,
                percentage: 1e6,
                tokenOut: address(0)
            })
        );
    }

    function test_refundNative() public {
        address target = makeAddr("target");
        uint256 value = 1 ether;
        bytes memory callData = "";

        UserOpData memory userOpData =
            instance.getExecOps(target, value, callData, address(licensedValidator));

        // sign userOp with default signature
        userOpData.userOp.paymasterAndData = abi.encodePacked(
            address(paymaster),
            uint128(100_000),
            uint128(100_000),
            uint8(0),
            uint48(type(uint48).max),
            uint48(0)
        );

        userOpData.execUserOps();

        assertTrue(
            IStakeManager(address(instance.aux.entrypoint)).balanceOf(address(paymaster)) > 1 ether
        );

        assertTrue(token.balanceOf(receiver.addr) == 13); // 1% of 1337
    }

    function test_refundWETH() public {
        address target = makeAddr("target");
        uint256 value = 1 ether;
        bytes memory callData = "";

        UserOpData memory userOpData =
            instance.getExecOps(target, value, callData, address(licensedValidator));

        // sign userOp with default signature
        userOpData.userOp.paymasterAndData = abi.encodePacked(
            address(paymaster),
            uint128(100_000),
            uint128(100_000),
            uint8(1),
            uint48(type(uint48).max),
            uint48(0)
        );

        userOpData.execUserOps();

        assertTrue(
            IStakeManager(address(instance.aux.entrypoint)).balanceOf(address(paymaster)) > 1 ether
        );

        assertTrue(token.balanceOf(receiver.addr) == 13); // 1% of 1337
    }
}
