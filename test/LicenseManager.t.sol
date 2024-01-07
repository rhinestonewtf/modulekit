// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/ModuleKit.sol";
import "src/Modules.sol";
import "src/core/sessionKey/ISessionValidationModule.sol";
import "src/Mocks.sol";
import { LicenseValidator, LicenseCollector } from "src/core/Licensing/LicenseManager.sol";
import { LicensedModule } from "src/core/Licensing/LicensedModule.sol";
import { SignatureCheckerLib } from "solady/src/utils/SignatureCheckerLib.sol";
import { Solarray } from "solarray/Solarray.sol";

contract LicenseManagerTest is RhinestoneModuleKit, Test {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount internal instance;

    LicenseValidator internal validator;
    LicenseCollector internal collector;
    LicensedModule internal licensedModule;

    bytes32 internal sessionValidatorDigest;
    MockTarget internal target;
    MockERC20 internal token;

    address keySigner1;
    uint256 keySignerPk1;

    function setUp() public {
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 1 ether);

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);

        collector = new LicenseCollector(instance.aux.entrypoint);
        validator = collector.validator();
        licensedModule = new LicensedModule(address(validator), address(token));

        target = new MockTarget();

        (keySigner1, keySignerPk1) = makeAddrAndKey("KeySigner1");

        instance.installValidator(address(validator));
        instance.installExecutor(address(licensedModule));
    }

    function test_collectFees() public {
        address[] memory modules = Solarray.addresses(address(licensedModule));

        uint256 total = collector.calcFees(instance.account, address(token), modules);

        uint gasL = gasleft();
        collector.collectFee(instance.account, address(token), modules, total);
        gasL = gasL - gasleft();

        console.log("gas used: ", gasL);

        assertEq(token.balanceOf(address(collector)), total);
    }
}
