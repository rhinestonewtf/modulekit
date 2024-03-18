import "forge-std/Test.sol";
import "src/LicenseManager.sol";
import "src/core/SplitterConf.sol";
import "src/utils/TxFeeSigner.sol";

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
import { Solarray } from "solarray/Solarray.sol";

contract LicenseTest is RhinestoneModuleKit, DeployPermit2, Test {
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
    SplitterConf splitterConf;
    TxFeeSigner signer;

    function setUp() public {
        vm.warp(123_123_123);
        instance = makeAccountInstance("instance");
        instance.deployAccount();
        vm.deal(instance.account, 100 ether);
        permit2 = deployPermit2();
        token = new MockERC20();
        splitterConf = new SplitterConf();
        splitterConf.setConf(module.addr, Solarray.uint256s(90, 10));

        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);
        deal(instance.account, 100 ether);
        licenseMgr = new LicenseManager(IPermit2(permit2), address(token), splitterConf);
        signer = new TxFeeSigner(permit2, address(licenseMgr));
        licenseMgr.initialize(address(signer));
        licenseMgr.moduleRegistration(module.addr, receiver.addr);

        vm.prank(instance.account);
        token.approve(permit2, type(uint256).max);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(signer),
            data: ""
        });
        vm.prank(instance.account);
        signer.configure(module.addr, true);
    }

    function test_claimTxFee() public {
        vm.startPrank(module.addr);

        licenseMgr.permitTxFee(instance.account, 100, hex"41414141414141414141414141414141414141");
    }
}
