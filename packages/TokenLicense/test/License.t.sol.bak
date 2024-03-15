// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/LicenseManager.sol";
import "src/AutoLicense.sol";
import { MODULE_TYPE_VALIDATOR } from "@rhinestone/modulekit/src/external/ERC7579.sol";
import "@rhinestone/modulekit/src/Mocks.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import "@rhinestone/modulekit/src/Helpers.sol";

contract LicenseTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    LicenseManager license;
    AutoLicense validator;
    MockERC20 internal token;

    AccountInstance internal instance;

    Account module;
    Account dev;
    Account signer;

    function setUp() public {
        vm.warp(17_923_123);
        instance = makeAccountInstance("smartaccount");
        module = makeAccount("module");
        dev = makeAccount("dev");
        signer = makeAccount("signer");

        token = new MockERC20();
        license = new LicenseManager(address(token));
        validator = new AutoLicense(license);
        token.initialize("USDC", "USDC", 18);
        deal(address(token), instance.account, 100 ether);
        vm.deal(instance.account, 1000 ether);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });

        _setupModule();
    }

    function _setupModule() public {
        license.resolveModuleRegistration(
            address(0),
            module.addr,
            abi.encode(
                IDistributor.ModuleMonetization({
                    owner: dev.addr,
                    pricePerSecond: 100,
                    beneficiary: dev.addr
                })
            )
        );
    }

    modifier assertLicenseTimes() {
        assertEq(license.licenseUntil(instance.account, module.addr), 0);
        assertEq(license.hasActiveLicense(instance.account, module.addr), false);
        _;

        assertEq(license.licenseUntil(instance.account, module.addr), 17_923_123 + 1000);
        assertEq(license.hasActiveLicense(instance.account, module.addr), true);

        vm.warp(17_923_123 + 1000);
        assertEq(license.hasActiveLicense(instance.account, module.addr), false);
    }

    modifier assertSplit() {
        _;
        GasliteSplitterFactory factory = license.splitterFactory();
        address[] memory recipients = new address[](2);
        recipients[0] = dev.addr;
        recipients[1] = address(this);

        uint256[] memory shares = new uint256[](2);
        shares[0] = 90;
        shares[1] = 10;
        GasliteSplitter splitter = GasliteSplitter(
            payable(
                factory.deployContract(
                    recipients, shares, false, keccak256(abi.encodePacked(module.addr))
                )
            )
        );
        splitter.release(address(token));

        assertTrue(token.balanceOf(dev.addr) > 0);
        assertTrue(token.balanceOf(address(this)) > 0);
    }

    function testLicense() public assertLicenseTimes assertSplit {
        vm.startPrank(instance.account);

        token.approve(address(license), type(uint256).max);

        license.distribute(
            IDistributor.FeeDistribution({ module: module.addr, amount: 100 * 1000 seconds })
        );
    }

    function test_sessionkeyExtend() public assertLicenseTimes {
        vm.startPrank(instance.account);

        validator.setPermission({
            module: module.addr,
            permission: AutoLicense.Permission({ signer: signer.addr, autoExtendEnabled: true })
        });
        validator.setLimit(100 ether);

        vm.stopPrank();

        Execution[] memory approveAndPay = new Execution[](2);
        approveAndPay[0] = Execution({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(MockERC20.approve, (address(license), 1 ether))
        });
        approveAndPay[1] = Execution({
            target: address(license),
            value: 0,
            callData: abi.encodeCall(
                IDistributor.distribute,
                (IDistributor.FeeDistribution({ module: module.addr, amount: 100 * 1000 seconds }))
                )
        });
        UserOpData memory userOpData = instance.getExecOps(approveAndPay, address(validator));

        userOpData.userOp.signature =
            ecdsaSign(signer.key, ECDSA.toEthSignedMessageHash(userOpData.userOpHash));

        userOpData.execUserOps();
    }
}
