import "forge-std/Test.sol";
import "src/LicenseRouter.sol";

import "forge-std/Test.sol";
import "@rhinestone/modulekit/src/ModuleKit.sol";
import "@rhinestone/modulekit/src/Mocks.sol";
import "@rhinestone/modulekit/src/Helpers.sol";
import "@rhinestone/modulekit/src/Core.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "@rhinestone/modulekit/src/external/ERC7579.sol";

import { DeployPermit2 } from "permit2/test/utils/DeployPermit2.sol";

import { Module } from "src/Module.sol";

contract LicenseRouterTest is RhinestoneModuleKit, DeployPermit2, Test {
    using ModuleKitHelpers for *;
    using ModuleKitSCM for *;
    using ModuleKitUserOp for *;

    LicenseRouter public licenseRouter;
    AccountInstance internal instance;

    Account internal receiver = makeAccount("receiver");
    Account internal registry = makeAccount("registry");
    MockERC20 internal token;
    address permit2;

    Module module;

    function setUp() public {
        vm.warp(123_123_123);
        instance = makeAccountInstance("instance");
        vm.deal(instance.account, 100 ether);
        permit2 = deployPermit2();
        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);
        deal(instance.account, 100 ether);
        licenseRouter = new LicenseRouter(address(token), permit2, registry.addr);
        module = new Module(address(licenseRouter));

        _setupModule();
    }

    function _setupModule() public {
        vm.prank(registry.addr);
        licenseRouter.registerModule(
            address(module),
            LicenseRouter.ModuleLicense({
                isTransferable: false,
                renewals: 30 days,
                beneficiary: receiver.addr,
                price: 10,
                txPercentage: 10
            })
        );
    }

    function test_mintLicense_self() public {
        vm.startPrank(instance.account);
        token.approve(address(licenseRouter), 1 ether);
        licenseRouter.mintLicense(instance.account, address(module));
        module.mockFeature();
        vm.warp(block.timestamp + 31 days);
        vm.expectRevert();
        module.mockFeature();
        vm.stopPrank();
    }

    function test_mintLicense_signature() public {
        vm.startPrank(instance.account);
        token.approve(address(permit2), 100 ether);
        module.initSub({
            signature: abi.encodePacked(address(instance.defaultValidator), hex"4141414141414141414141")
        });
        module.mockFeature();
        vm.stopPrank();
    }
}
