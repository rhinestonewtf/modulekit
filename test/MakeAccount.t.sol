// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable no-global-import */
import "forge-std/Test.sol";
import "src/ModuleKit.sol";
import "src/Mocks.sol";
/* solhint-enable no-global-import */

contract BaseTest is RhinestoneModuleKit, Test {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount internal instance;

    function setUp() public {
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 1 ether);
    }
}
