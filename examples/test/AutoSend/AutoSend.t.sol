// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "modulekit/src/ModuleKit.sol";
import "modulekit/src/Modules.sol";
import "modulekit/src/Mocks.sol";
import { AutoSendSessionKey } from "src/AutoSend/AutoSend.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { Solarray } from "solarray/Solarray.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/src/external/ERC7579.sol";

contract AutoSendTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using ModuleKitSCM for *;

    AccountInstance internal instance;

    AutoSendSessionKey internal sessionValidator;
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

        sessionValidator = new AutoSendSessionKey();
        target = new MockTarget();
        recipient = makeAddr("recipient");

        (keySigner1, keySignerPk1) = makeAddrAndKey("KeySigner1");

        AutoSendSessionKey.ExecutorAccess memory _tx1 = AutoSendSessionKey.ExecutorAccess({
            sessionKeySigner: keySigner1,
            token: address(token),
            receiver: recipient
        });

        (, sessionValidatorDigest) = instance.installSessionKey({
            sessionKeyModule: (address(sessionValidator)),
            validUntil: type(uint48).max,
            validAfter: 0,
            sessionKeyData: sessionValidator.encode(_tx1),
            txValidator: address(instance.defaultValidator)
        });

        // params for executor install
        address[] memory tokens = Solarray.addresses(address(token));
        AutoSendSessionKey.SpentLog[] memory logs = new AutoSendSessionKey.SpentLog[](1);
        logs[0] = AutoSendSessionKey.SpentLog({ spent: 0, maxAmount: 100 });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(sessionValidator),
            data: abi.encode(tokens, logs)
        });
    }

    function test_transferBatch() public {
        AutoSendSessionKey.Params memory params =
            AutoSendSessionKey.Params({ token: address(token), receiver: recipient, amount: 33 });

        address[] memory targets =
            Solarray.addresses(address(sessionValidator), address(sessionValidator));
        uint256[] memory values = Solarray.uint256s(uint256(0), uint256(0));
        bytes[] memory calldatas = Solarray.bytess(
            abi.encodeCall(AutoSendSessionKey.autoSend, (params)),
            abi.encodeCall(AutoSendSessionKey.autoSend, (params))
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

        assertEq(token.balanceOf(recipient), 66);

        AutoSendSessionKey.SpentLog memory log =
            sessionValidator.getSpentLog(instance.account, address(token));

        assertEq(log.spent, 66);
        assertEq(log.maxAmount, 100);
    }

    function sign(uint256 privKey, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_transferSingle() public {
        AutoSendSessionKey.Params memory params =
            AutoSendSessionKey.Params({ token: address(token), receiver: recipient, amount: 33 });
        bytes memory sig = sign(keySignerPk1, sessionValidatorDigest);

        bool isValid =
            SignatureCheckerLib.isValidSignatureNow(keySigner1, sessionValidatorDigest, sig);

        assertTrue(isValid);
        instance.getExecOps({
            target: address(sessionValidator),
            value: 0,
            callData: abi.encodeCall(AutoSendSessionKey.autoSend, (params)),
            sessionKeyDigest: sessionValidatorDigest,
            sessionKeySignature: sig,
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        assertEq(token.balanceOf(recipient), 33);
    }
}
