// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/ModuleKit.sol";
import "src/Modules.sol";
import "src/Mocks.sol";
import { ERC20SessionKey } from "src/modules/sessionKeys/ERC20SessionKey.sol";

contract ERC20SessionValidatorTest is RhinestoneModuleKit, Test {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount internal instance;

    ERC20SessionKey internal sessionValidator;
    bytes32 internal sessionValidatorDigest;
    MockTarget internal target;
    MockERC20 internal token;

    address internal recipient;

    function setUp() public {
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 1 ether);

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);

        sessionValidator = new ERC20SessionKey();
        target = new MockTarget();
        recipient = makeAddr("recipient");

        ERC20SessionKey.ERC20Transaction memory _tx = ERC20SessionKey.ERC20Transaction({
            token: address(token),
            recipient: recipient,
            maxAmount: 1000
        });

        sessionValidatorDigest = instance.installSessionKey({
            sessionKeyModule: address(sessionValidator),
            validUntil: type(uint48).max,
            validAfter: 0,
            sessionKeyData: abi.encode(_tx)
        });
    }

    function test_execWithSessionKey__ShouldFail() public {
        instance.exec4337({
            target: address(target),
            value: 0,
            callData: abi.encodeCall(MockTarget.set, (123)),
            sessionKeyDigest: sessionValidatorDigest,
            sessionKeySignature: hex"414141414141"
        });

        assertEq(target.value(), 123);
    }

    function test_transfer() public {
        instance.exec4337({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(MockERC20.transfer, (recipient, 100)),
            sessionKeyDigest: sessionValidatorDigest,
            sessionKeySignature: hex"414141414141"
        });

        assertEq(token.balanceOf(recipient), 100);
    }
}
