// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "modulekit/src/ModuleKit.sol";
import "modulekit/src/Helpers.sol";
import "modulekit/src/Core.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "solmate/test/utils/mocks/MockERC4626.sol";
import { AutoSavingToVault } from "src/AutoSavings/AutoSavings.sol";

import { MODULE_TYPE_EXECUTOR } from "modulekit/src/external/ERC7579.sol";

contract AutoSavingsTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;
    AutoSavingToVault internal autosavings;

    MockERC20 internal tokenIn;
    MockERC20 internal tokenOut;
    MockERC4626 internal vault1;
    MockERC4626 internal vault2;

    bytes internal sessionKeyData;

    Account internal signer = makeAccount("signer");

    bytes32 internal sessionKeyDigest;

    function setUp() public {
        instance = makeAccountInstance("instance");
        vm.warp(17_999_999);

        autosavings = new AutoSavingToVault();
        tokenIn = new MockERC20("USDC", "USDC", 18);
        vm.label(address(tokenIn), "USDC");
        tokenIn.mint(instance.account, 1_000_000);
        tokenOut = new MockERC20("wETH", "wETH", 18);
        vm.label(address(tokenIn), "wETH");
        tokenOut.mint(instance.account, 1_000_000);

        vault1 = new MockERC4626(tokenIn, "vUSDC", "vUSDC");
        vault2 = new MockERC4626(tokenOut, "vwETH", "vwETH");

        sessionKeyData = abi.encode(
            AutoSavingToVault.ScopedAccess({
                sessionKeySigner: signer.addr,
                onlyToken: address(tokenIn),
                maxAmount: 10_000 ** 18
            })
        );

        (, sessionKeyDigest) = instance.installSessionKey({
            sessionKeyModule: address(autosavings),
            validUntil: uint48(block.timestamp + 7 days),
            validAfter: uint48(block.timestamp - 7 days),
            sessionKeyData: sessionKeyData,
            txValidator: address(instance.defaultValidator)
        });

        AutoSavingToVault.Config memory savingForToken = AutoSavingToVault.Config({
            percentage: 100, // 100 = 1%
            vault: address(vault2),
            sqrtPriceLimitX96: 0
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(autosavings),
            data: ""
        });
        vm.prank(instance.account);
        autosavings.setConfig({ token: address(tokenIn), config: savingForToken });
    }

    modifier whenModuleIsCalled() {
        _;
    }

    function test_WhenSignerIsInvalid() external whenModuleIsCalled {
        // It should not validate
        // It should execute deposit
    }

    function test_WhenSignerIsValid() external whenModuleIsCalled {
        // It should deposit
        AutoSavingToVault.Params memory params =
            AutoSavingToVault.Params({ token: address(tokenIn), amountReceived: 100 });
        instance.getExecOps({
            target: address(autosavings),
            value: 0,
            callData: abi.encodeCall(AutoSavingToVault.autoSave, (params)),
            sessionKeyDigest: sessionKeyDigest,
            sessionKeySignature: ecdsaSign(signer.key, sessionKeyDigest),
            txValidator: address(instance.defaultValidator)
        }).execUserOps();
        // It should deposit correct percentage
        // It should update spending limit
    }

    function test_WhenDepositAmountLargerThanMax() external whenModuleIsCalled {
        // It should revert
    }
}
