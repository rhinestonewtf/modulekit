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
import "src/signer/TxFeeSigner.sol";
import "src/signer/SubscriptionSigner.sol";

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
    TxFeeSigner txSigner;
    SubscriptionSigner subSigner;
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
        deal(address(usdc), instance.account, 100_000 ether);
        deal(address(weth), instance.account, 100_000 ether);
        vm.label(address(usdc), "USDC");
        vm.label(address(weth), "WETH");
        deal(instance.account, 100 ether);
        licenseMgr = new LicenseManager(IPermit2(permit2), poolFactory, usdc);
        txSigner = new TxFeeSigner(permit2, address(licenseMgr));
        subSigner = new SubscriptionSigner(permit2, address(licenseMgr));
        feemachine = new FeeMachine();
        licenseMgr.initSigners(
            address(txSigner), address(txSigner), address(subSigner), address(subSigner)
        );

        feemachine.setShareholder(module.addr, bps.wrap(500), feemachines);
        feemachine.setreferral(referral, bps.wrap(5000));
        // licenseMgr.init(bps.wrap(1000));

        vm.startPrank(instance.account);
        IERC20(usdc).approve(permit2, type(uint256).max);
        weth.approve(permit2, type(uint256).max);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(txSigner),
            data: ""
        });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(subSigner),
            data: ""
        });
        TxFeeSigner.TxConfig memory config =
            TxFeeSigner.TxConfig({ enabled: true, maxTxPercentage: bps.wrap(500) });
        txSigner.configure(module.addr, config);
        subSigner.configure(module.addr, true);

        vm.stopPrank();

        licenseMgr.newFeeMachine(module.addr, IFeeMachine(address(feemachine)));
    }
}
