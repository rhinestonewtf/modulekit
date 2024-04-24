// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "modulekit/src/ModuleKit.sol";
import "modulekit/src/Modules.sol";
import "modulekit/src/Mocks.sol";
import { ERC20Revocation } from "src/TokenRevocation/ERC20Revocation.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { Solarray } from "solarray/Solarray.sol";

contract ERC20RevocationTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using ModuleKitSCM for *;

    AccountInstance internal instance;

    ERC20Revocation internal sessionValidator;
    bytes32 internal sessionValidatorDigest;
    MockTarget internal target;
    MockERC20 internal token;

    address internal recipient;

    address keySigner1;
    uint256 keySignerPk1;

    function setUp() public {
        instance = makeAccountInstance("1");
        vm.deal(instance.account, 1 ether);

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);

        sessionValidator = new ERC20Revocation();
        target = new MockTarget();
        recipient = makeAddr("recipient");

        (keySigner1, keySignerPk1) = makeAddrAndKey("KeySigner1");

        ERC20Revocation.Token memory _tx1 = ERC20Revocation.Token({
            token: address(token),
            tokenType: ERC20Revocation.TokenType.ERC20,
            sessionKeySigner: keySigner1
        });
        UserOpData memory userOpData;
        (userOpData, sessionValidatorDigest) = instance.installSessionKey({
            sessionKeyModule: (address(sessionValidator)),
            validUntil: type(uint48).max,
            validAfter: 0,
            sessionKeyData: sessionValidator.encode(_tx1),
            txValidator: address(instance.defaultValidator)
        });

        userOpData.execUserOps();

        vm.prank(instance.account);
        token.approve(recipient, 100);
    }

    function test_transferBatch() public {
        assertEq(token.allowance(instance.account, recipient), 100);
        address[] memory targets = Solarray.addresses(address(token), address(token));
        uint256[] memory values = Solarray.uint256s(uint256(0), uint256(0));
        bytes[] memory calldatas = Solarray.bytess(
            abi.encodeCall(MockERC20.approve, (recipient, 0)),
            abi.encodeCall(MockERC20.approve, (makeAddr("foo"), 0))
        );

        bytes32[] memory sessionKeyDigests =
            Solarray.bytes32s(sessionValidatorDigest, sessionValidatorDigest);

        bytes[] memory sessionKeySignatures = Solarray.bytess(
            sign(keySignerPk1, sessionValidatorDigest), sign(keySignerPk1, sessionValidatorDigest)
        );
        instance.getExecOps({
            targets: targets,
            values: values,
            callDatas: calldatas,
            sessionKeyDigests: sessionKeyDigests,
            sessionKeySignatures: sessionKeySignatures,
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        assertEq(token.allowance(instance.account, recipient), 0);
    }

    function sign(uint256 privKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_transferSingle() public {
        assertEq(token.allowance(instance.account, recipient), 100);
        bytes memory sig = sign(keySignerPk1, sessionValidatorDigest);

        bool isValid =
            SignatureCheckerLib.isValidSignatureNow(keySigner1, sessionValidatorDigest, sig);

        assertTrue(isValid);
        instance.getExecOps({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(MockERC20.approve, (recipient, 0)),
            sessionKeyDigest: sessionValidatorDigest,
            sessionKeySignature: sig,
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        assertEq(token.allowance(instance.account, recipient), 0);
    }
}
