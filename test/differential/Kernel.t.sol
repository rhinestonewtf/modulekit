// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    RhinestoneModuleKitLib,
    RhinestoneAccount,
    UserOperation,
    ConditionConfig
} from "../../src/test/utils/kernel-base/RhinestoneModuleKit.sol";
import { MockValidator } from "../../src/test/mocks/MockValidator.sol";
import { MockHook } from "../../src/test/mocks/MockHook.sol";
import { MockExecutor } from "../../src/test/mocks/MockExecutor.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { IERC721TokenReceiver } from "forge-std/interfaces/IERC721.sol";
import { ICondition } from "../../src/core/ComposableCondition.sol";
import { TokenReceiver } from "../mocks/fallback/TokenReceiver.sol";
import { Merkle } from "murky/Merkle.sol";
import { MockCondition } from "../../src/test/mocks/MockCondition.sol";

contract KernelDifferentialModuleKitLibTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount instance;
    MockValidator validator;
    MockHook hook;
    MockExecutor executor;

    MockERC20 token;

    function setUp() public {
        // Setup account
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 10 ether);

        // Setup modules
        validator = new MockValidator();
        hook = new MockHook();
        executor = new MockExecutor();

        // Setup aux
        token = new MockERC20("Test", "TEST", 18);
        token.mint(instance.account, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                EXEC4337
    //////////////////////////////////////////////////////////////////////////*/

    function testExec4337__Given__TwoInputs() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData =
            abi.encodeWithSignature("transfer(address,uint256)", receiver, value);

        // Create userOperation
        instance.exec4337({ target: address(token), callData: callData });

        // Validate userOperation
        assertEq(token.balanceOf(receiver), value, "Receiver should have 10 gwei in tokens");
    }

    function testExec4337__Given__ThreeInputs() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";

        // Create userOperation
        instance.exec4337({ target: receiver, value: value, callData: callData });

        // Validate userOperation
        assertEq(receiver.balance, value, "Receiver should have 10 gwei");
    }

    function testExec4337__Given__FourInputs() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        instance.exec4337({
            target: receiver,
            value: value,
            callData: callData,
            signature: signature
        });

        // Validate userOperation
        assertEq(receiver.balance, value, "Receiver should have 10 gwei");
    }

    function testExec4337__RevertWhen__UserOperationFails() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 100_000 ether;

        // Create userOperation
        instance.expect4337Revert();
        instance.exec4337({ target: receiver, callData: "", value: value });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODULES
    //////////////////////////////////////////////////////////////////////////*/

    function testAddValidator() public {
        address newValidator = makeAddr("validator");

        instance.addValidator(newValidator);
        bool validatorEnabled = instance.isValidatorEnabled(newValidator);
        assertTrue(validatorEnabled);
    }

    function testRemoveValidator() public {
        address newValidator = makeAddr("validator");

        instance.addValidator(newValidator);
        bool validatorEnabled = instance.isValidatorEnabled(newValidator);
        assertTrue(validatorEnabled);

        instance.removeValidator(newValidator);
        validatorEnabled = instance.isValidatorEnabled(newValidator);
        assertFalse(validatorEnabled);
    }

    function testAddSessionKey() public {
        uint256 validUntil = block.timestamp + 1 days;
        uint256 validAfter = block.timestamp;
        address sessionValidationModule = address(validator);
        bytes memory sessionKeyData = "";

        instance.addSessionKey({
            validUntil: validUntil,
            validAfter: validAfter,
            sessionValidationModule: sessionValidationModule,
            sessionKeyData: sessionKeyData
        });

        // Validate proof
        Merkle m = new Merkle();

        bytes32 leaf = instance.aux.sessionKeyManager._sessionMerkelLeaf({
            validUntil: validUntil,
            validAfter: validAfter,
            sessionValidationModule: sessionValidationModule,
            sessionKeyData: sessionKeyData
        });

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = leaf;
        leaves[1] = leaf;

        bytes32 root = instance.aux.sessionKeyManager.getSessionKeys(instance.account).merkleRoot;
        bytes32[] memory proof = m.getProof(leaves, 1);

        bool isValidProof = m.verifyProof(root, proof, leaf);

        assertTrue(isValidProof);
    }

    function testAddHook() public {
        vm.expectRevert();
        instance.addHook(address(hook));

        vm.expectRevert();
        bool hookEnabled = instance.isHookEnabled(address(hook));
        assertTrue(hookEnabled);
    }

    function testAddExecutor() public {
        address newExecutor = makeAddr("executor");

        instance.addExecutor(newExecutor);
        bool executorEnabled = instance.isExecutorEnabled(newExecutor);
        assertTrue(executorEnabled);
    }

    function testRemoveExecutor() public {
        address newExecutor = makeAddr("executor");

        instance.addExecutor(newExecutor);
        bool executorEnabled = instance.isExecutorEnabled(newExecutor);
        assertTrue(executorEnabled);

        instance.removeExecutor(newExecutor);
        executorEnabled = instance.isValidatorEnabled(newExecutor);
        assertFalse(executorEnabled);
    }

    function testSetCondition() public {
        address newExecutor = makeAddr("newExecutor");
        instance.addExecutor(newExecutor);

        address mockCondition = address(new MockCondition());
        ConditionConfig[] memory conditions = new ConditionConfig[](1);
        conditions[0] = ConditionConfig({ condition: ICondition(mockCondition), conditionData: "" });

        bytes32 digest = instance.aux.compConditionManager._conditionDigest(conditions);

        instance.setCondition(newExecutor, conditions);

        bytes32 digestOnManager =
            instance.aux.compConditionManager.getHash(instance.account, newExecutor);
        assertEq(digest, digestOnManager);
    }

    function testAddFallback() public {
        TokenReceiver handler = new TokenReceiver();
        bytes4 functionSig = IERC721TokenReceiver.onERC721Received.selector;

        bytes memory callData = abi.encodeWithSelector(
            functionSig, makeAddr("foo"), makeAddr("foo"), uint256(1), bytes("foo")
        );

        instance.addFallback({
            handleFunctionSig: functionSig,
            isStatic: true,
            handler: address(handler)
        });

        (bool success,) = instance.account.call(callData);
        assertTrue(success);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                UTILS
    //////////////////////////////////////////////////////////////////////////*/

    function testGetUserOpHash() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = abi.encode(true);

        // Create userOperation hash using lib
        bytes32 userOpHash =
            instance.getUserOpHash({ target: receiver, value: value, callData: callData });

        UserOperation memory userOp =
            instance.getFormattedUserOp({ target: receiver, value: value, callData: callData });
        bytes32 entryPointUserOpHash = instance.aux.entrypoint.getUserOpHash(userOp);

        // Validate userOperation
        assertEq(userOpHash, entryPointUserOpHash);
    }
}
