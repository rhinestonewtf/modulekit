// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import "@rhinestone/modulekit/src/Mocks.sol";
import "@rhinestone/modulekit/src/Helpers.sol";
import "@rhinestone/modulekit/src/Core.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "@rhinestone/modulekit/src/external/ERC7579.sol";

import "src/LicenseManager.sol";
import "src/splitter/FeeMachine.sol";
import "src/splitter/IFeeMachine.sol";
import "src/signer/MultiSigner.sol";

import { DeployPermit2 } from "permit2/test/utils/DeployPermit2.sol";
import { Solarray } from "solarray/Solarray.sol";
import "forge-std/Test.sol";
import "./Fork.t.sol";

contract BaseTest is RhinestoneModuleKit, DeployPermit2, ForkTest {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    AccountInstance internal instance;

    Account internal receiver = makeAccount("receiver");
    Account internal registry = makeAccount("registry");
    Account internal module = makeAccount("module");
    MockERC20 internal token;
    address permit2;

    LicenseManager licenseMgr;
    MultiSigner signer;
    FeeMachine feemachine;

    address feemachine1;
    address feemachine2;
    address feemachine3;
    address referral;

    function setUp() public virtual override {
        super.setUp();

        feemachine1 = makeAddr("shareholder1");
        feemachine2 = makeAddr("shareholder2");
        feemachine3 = makeAddr("shareholder3");
        referral = makeAddr("referral");

        ShareholderData[] memory feemachines = new ShareholderData[](3);
        feemachines[0] = ShareholderData(feemachine1, 9900);
        feemachines[1] = ShareholderData(feemachine2, 90);
        feemachines[2] = ShareholderData(feemachine3, 10);

        instance = makeAccountInstance("instance");
        instance.deployAccount();
        vm.deal(instance.account, 100 ether);
        permit2 = deployPermit2();
        vm.label(permit2, "Permit2");
        deal(address(usdc), instance.account, 100_000 ether);
        deal(address(weth), instance.account, type(uint256).max);
        vm.label(address(usdc), "USDC");
        vm.label(address(weth), "WETH");
        deal(instance.account, 100 ether);
        licenseMgr = new LicenseManager(IPermit2(permit2), poolFactory, usdc);
        vm.label(address(licenseMgr), "LicenseManager");
        signer = new MultiSigner(permit2, address(licenseMgr));
        feemachine = new FeeMachine();
        licenseMgr.initSigners(address(signer));

        feemachine.setShareholder(module.addr, bps.wrap(500), feemachines);
        feemachine.setreferral(referral, bps.wrap(5000));
        // licenseMgr.init(bps.wrap(1000));

        vm.startPrank(instance.account);
        IERC20(usdc).approve(permit2, type(uint256).max);
        weth.approve(permit2, type(uint256).max);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(signer),
            data: ""
        });

        ClaimType[] memory claimTypes = new ClaimType[](3);
        claimTypes[0] = ClaimType.Transaction;
        claimTypes[1] = ClaimType.Subscription;
        claimTypes[2] = ClaimType.SingleCharge;

        MultiSigner.FeePermissions[] memory permissions = new MultiSigner.FeePermissions[](3);
        permissions[0] = MultiSigner.FeePermissions({ enabled: true, usdAmountMax: 1000 ether });
        permissions[1] = MultiSigner.FeePermissions({ enabled: true, usdAmountMax: 1000 ether });
        permissions[2] = MultiSigner.FeePermissions({ enabled: true, usdAmountMax: 1000 ether });

        signer.configureSelfPay(module.addr, claimTypes, permissions);

        vm.stopPrank();

        licenseMgr.newFeeMachine(module.addr, IFeeMachine(address(feemachine)));
    }
}
