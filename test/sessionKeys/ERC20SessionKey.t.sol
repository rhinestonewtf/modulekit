// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/ModuleKit.sol";
import "src/Modules.sol";
import "src/core/sessionKey/ISessionValidationModule.sol";
import { SessionData, SessionKeyManagerLib } from "src/core/sessionKey/SessionKeyManagerLib.sol";
import "src/Mocks.sol";
import { ERC20SessionKey } from "src/modules/sessionKeys/ERC20SessionKey.sol";
import { SignatureCheckerLib } from "solady/src/utils/SignatureCheckerLib.sol";
import { Solarray } from "solarray/Solarray.sol";

contract ERC20SessionValidatorTest is RhinestoneModuleKit, Test {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount internal instance;

    ERC20SessionKey internal sessionValidator;
    bytes32 internal sessionValidatorDigest;
    MockTarget internal target;
    MockERC20 internal token;

    address internal recipient;

    address keySigner1;
    uint256 keySignerPk1;

    address keySigner2;
    uint256 keySignerPk2;

    function setUp() public {
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 1 ether);

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);

        sessionValidator = new ERC20SessionKey();
        target = new MockTarget();
        recipient = makeAddr("recipient");

        (keySigner1, keySignerPk1) = makeAddrAndKey("KeySigner1");
        (keySigner2, keySignerPk2) = makeAddrAndKey("KeySigner1");

        ERC20SessionKey.ERC20Transaction memory _tx1 = ERC20SessionKey.ERC20Transaction({
            token: address(token),
            recipient: recipient,
            maxAmount: 1000,
            sessionKeySigner: keySigner1
        });

        sessionValidatorDigest = instance.installSessionKey({
            sessionKeyModule: (address(sessionValidator)),
            validUntil: type(uint48).max,
            validAfter: 0,
            sessionKeyData: sessionValidator.encode(_tx1)
        });
    }

    function test_transferBatch() public {
        address[] memory targets = Solarray.addresses(address(token), address(token));
        uint256[] memory values = Solarray.uint256s(uint256(0), uint256(0));
        bytes[] memory calldatas = Solarray.bytess(
            abi.encodeCall(MockERC20.transfer, (recipient, 22)),
            abi.encodeCall(MockERC20.transfer, (recipient, 11))
        );

        bytes32[] memory sessionKeyDigests =
            Solarray.bytes32s(sessionValidatorDigest, sessionValidatorDigest);

        bytes[] memory sessionKeySignatures = Solarray.bytess(
            sign(keySignerPk1, sessionValidatorDigest), sign(keySignerPk1, sessionValidatorDigest)
        );
        instance.exec4337({
            targets: targets,
            values: values,
            callDatas: calldatas,
            sessionKeyDigests: sessionKeyDigests,
            sessionKeySignatures: sessionKeySignatures
        });

        assertEq(token.balanceOf(recipient), 33);
    }

    function sign(uint256 privKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_transferSingle() public {
        bytes memory sig = sign(keySignerPk1, sessionValidatorDigest);

        bool isValid =
            SignatureCheckerLib.isValidSignatureNow(keySigner1, sessionValidatorDigest, sig);

        assertTrue(isValid);
        instance.exec4337({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(MockERC20.transfer, (recipient, 100)),
            sessionKeyDigest: sessionValidatorDigest,
            sessionKeySignature: sig
        });

        assertEq(token.balanceOf(recipient), 100);
    }
}
