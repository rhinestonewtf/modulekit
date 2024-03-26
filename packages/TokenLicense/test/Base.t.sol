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

contract BaseTest is RhinestoneModuleKit, DeployPermit2, Test {
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
    FeeMachine shareholder;

    address shareholder1;
    address shareholder2;
    address shareholder3;
    address referral;

    function setUp() public virtual {
        vm.warp(123_123_123);

        shareholder1 = makeAddr("shareholder1");
        shareholder2 = makeAddr("shareholder2");
        shareholder3 = makeAddr("shareholder3");
        referral = makeAddr("referral");

        ShareholderData[] memory shareholders = new ShareholderData[](3);
        shareholders[0] = ShareholderData(shareholder1, 9900);
        shareholders[1] = ShareholderData(shareholder2, 90);
        shareholders[2] = ShareholderData(shareholder3, 10);

        instance = makeAccountInstance("instance");
        instance.deployAccount();
        vm.deal(instance.account, 100 ether);
        permit2 = deployPermit2();
        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);
        deal(instance.account, 100 ether);
        licenseMgr = new LicenseManager(IPermit2(permit2));
        txSigner = new TxFeeSigner(permit2, address(licenseMgr));
        subSigner = new SubscriptionSigner(permit2, address(licenseMgr));
        shareholder = new FeeMachine();
        licenseMgr.initSigners(
            address(txSigner), address(txSigner), address(subSigner), address(subSigner)
        );

        shareholder.setShareholder(module.addr, bps.wrap(500), shareholders);
        shareholder.setreferral(referral, bps.wrap(5000));
        // licenseMgr.init(bps.wrap(1000));

        vm.startPrank(instance.account);
        token.approve(permit2, type(uint256).max);

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

        licenseMgr.registerShareholder(module.addr, IFeeMachine(address(shareholder)));
    }
}
