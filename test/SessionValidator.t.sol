// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "src/ModuleKit.sol";
import "src/Modules.sol";
import "src/Mocks.sol";
import "src/core/ISessionKeyManagerHybrid.sol";

contract SessionValidatorTest is RhinestoneModuleKit, Test {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount instance;

    SessionKeyManagerHybrid sessionKeyManager;
    MockSessionKeyValidator sessionValidator;
    MockTarget target;

    function setUp() public {
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 1 ether);

        sessionKeyManager = new SessionKeyManagerHybrid();
        sessionValidator = new MockSessionKeyValidator();
        target = new MockTarget();
        instance.installValidator(address(sessionKeyManager));

        ISessionKeyManagerModuleHybrid.SessionData memory sessionData =
        ISessionKeyManagerModuleHybrid.SessionData({
            validUntil: type(uint48).max,
            validAfter: 0,
            sessionValidationModule: address(sessionValidator),
            sessionKeyData: ""
        });
        vm.prank(instance.account);
        sessionKeyManager.enableSession(sessionData);
    }

    function test_isDefaultValidatorEnabled() public {
        assertTrue(instance.isValidatorInstalled(address(instance.defaultValidator)));
    }

    function test_execWithSessionKey() public {
        bytes1 code = 0x00;
        bytes memory block = hex"4141414141414141414141414141414141";
        bytes memory signature = abi.encodePacked(code, block);
        instance.exec4337({
            target: address(target),
            value: 0,
            callData: abi.encodeCall(MockTarget.set, (123)),
            signature: signature,
            validator: address(sessionKeyManager)
        });
    }
}
