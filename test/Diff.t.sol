// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/* solhint-disable no-global-import */
import { Test } from "forge-std/Test.sol";
import "src/ModuleKit.sol";
import "src/Mocks.sol";
import { writeSimulateUserOp } from "src/test/utils/Log.sol";
/* solhint-enable no-global-import */

contract ERC7579DifferentialModuleKitLibTest is Test, RhinestoneModuleKit {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    RhinestoneAccount internal instance;
    MockValidator internal validator;
    MockHook internal hook;
    MockExecutor internal executor;
    MockTarget internal mockTarget;

    MockERC20 internal token;

    function setUp() public {
        // Setup account
        instance = makeRhinestoneAccount("account1");
        vm.deal(instance.account, 1000 ether);

        // Setup modules
        validator = new MockValidator();
        hook = new MockHook();
        executor = new MockExecutor();

        // Setup aux
        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);
        mockTarget = new MockTarget();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                exec
    //////////////////////////////////////////////////////////////////////////*/

    function testexec__Given__TwoInputs() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData =
            abi.encodeWithSignature("transfer(address,uint256)", receiver, value);

        // Create userOperation
        instance.exec({ target: address(token), callData: callData });

        // Validate userOperation
        assertEq(token.balanceOf(receiver), value, "Receiver should have 10 gwei in tokens");
    }

    function testexec__Given__ThreeInputs() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";

        // Create userOperation
        instance.exec({ target: receiver, value: value, callData: callData });

        // Validate userOperation
        assertEq(receiver.balance, value, "Receiver should have 10 gwei");
    }

    function testexec__Given__FourInputs() public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";
        bytes memory signature = "";

        // Create userOperation
        instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        // Validate userOperation
        assertEq(receiver.balance, value, "Receiver should have 10 gwei");
    }

    function testexec__RevertWhen__UserOperationFails() public {
        // Create userOperation fields
        bytes memory callData = abi.encodeWithSelector(MockTarget.setAccessControl.selector, 2);

        // Create userOperation
        instance.expect4337Revert();
        instance.exec({ target: address(mockTarget), callData: callData, value: 0 });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODULES
    //////////////////////////////////////////////////////////////////////////*/

    function testAddValidator() public {
        address newValidator = address(new MockValidator());
        address newValidator1 = address(new MockValidator());
        vm.label(newValidator, "2nd validator");

        instance.installValidator(newValidator);
        // instance.log4337Gas("testAddValidator()");
        // instance.enableGasLog();
        instance.installValidator(newValidator1);

        bool validatorEnabled = instance.isValidatorInstalled(newValidator);
        assertTrue(validatorEnabled);
        bool validator1Enabled = instance.isValidatorInstalled(newValidator1);
        assertTrue(validator1Enabled);
    }

    function testRemoveValidator() public {
        address newValidator = address(new MockValidator());
        instance.installValidator(newValidator);
        bool validatorEnabled = instance.isValidatorInstalled(newValidator);
        assertTrue(validatorEnabled);

        instance.uninstallValidator(newValidator);
        validatorEnabled = instance.isValidatorInstalled(newValidator);
        assertFalse(validatorEnabled);
    }

    function testAddSessionKey() public {
        // NOT IMPLEMENTED
        // uint256 validUntil = block.timestamp + 1 days;
        // uint256 validAfter = block.timestamp;
        // address sessionValidationModule = address(validator);
        // bytes memory sessionKeyData = "";
        //
        // instance.addSessionKey({
        //     validUntil: validUntil,
        //     validAfter: validAfter,
        //     sessionValidationModule: sessionValidationModule,
        //     sessionKeyData: sessionKeyData
        // });
        //
        // // Validate proof
        // Merkle m = new Merkle();
        //
        // bytes32 leaf = instance.aux.sessionKeyManager._sessionMerkelLeaf({
        //     validUntil: validUntil,
        //     validAfter: validAfter,
        //     sessionValidationModule: sessionValidationModule,
        //     sessionKeyData: sessionKeyData
        // });
        //
        // bytes32[] memory leaves = new bytes32[](2);
        // leaves[0] = leaf;
        // leaves[1] = leaf;
        //
        // bytes32 root =
        // instance.aux.sessionKeyManager.getSessionKeys(instance.account).merkleRoot;
        // bytes32[] memory proof = m.getProof(leaves, 1);
        //
        // bool isValidProof = m.verifyProof(root, proof, leaf);
        //
        // assertTrue(isValidProof);
    }

    function testAddHook() public {
        instance.installHook(address(hook));

        bool hookEnabled = instance.isHookInstalled(address(hook));
        assertTrue(hookEnabled);
    }

    function testAddExecutor() public {
        address newExecutor = address(new MockExecutor());

        instance.installExecutor(newExecutor);
        bool executorEnabled = instance.isExecutorInstalled(newExecutor);
        assertTrue(executorEnabled);
    }

    function testRemoveExecutor() public {
        address newExecutor = address(new MockExecutor());

        instance.installExecutor(newExecutor);
        bool executorEnabled = instance.isExecutorInstalled(newExecutor);
        assertTrue(executorEnabled);

        instance.uninstallExecutor(newExecutor);
        executorEnabled = instance.isExecutorInstalled(newExecutor);
        assertFalse(executorEnabled);
    }

    // function testSetCondition() public {
    //     address newExecutor = address(new MockExecutor());
    //     instance.addExecutor(newExecutor);
    //
    //     address mockCondition = address(new MockCondition());
    //     ConditionConfig[] memory conditions = new ConditionConfig[](1);
    //     conditions[0] = ConditionConfig({ condition: ICondition(mockCondition),
    // conditionData: ""
    // });
    //
    //     bytes32 digest =
    // instance.aux.compConditionManager._conditionDigest(conditions);
    //
    //     instance.setCondition(newExecutor, conditions);
    //
    //     bytes32 digestOnManager =
    //         instance.aux.compConditionManager.getHash(instance.account, newExecutor);
    //     assertEq(digest, digestOnManager);
    // }

    // function testAddFallback() public {
    //     TokenReceiver handler = new TokenReceiver();
    //     bytes4 functionSig = IERC721TokenReceiver.onERC721Received.selector;
    //
    //     bytes memory callData = abi.encodeWithSelector(
    //         functionSig, makeAddr("foo"), makeAddr("foo"), uint256(1), bytes("foo")
    //     );
    //
    //     instance.addFallback({
    //         handleFunctionSig: functionSig,
    //         isStatic: true,
    //         handler: address(handler)
    //     });
    //
    //     (bool success,) = instance.account.call(callData);
    //     assertTrue(success);
    // }

    /*//////////////////////////////////////////////////////////////////////////
                                UTILS
    //////////////////////////////////////////////////////////////////////////*/

    function testGetUserOpHash() public {
        // // Create userOperation fields
        // address receiver = makeAddr("receiver");
        // uint256 value = 10 gwei;
        // bytes memory callData = abi.encode(true);
        //
        // // Create userOperation hash using lib
        // bytes32 userOpHash =
        //     instance.getUserOpHash({ target: receiver, value: value, callData: callData });
        //
        // UserOperation memory userOp =
        //     instance.getFormattedUserOp({ target: receiver, value: value, callData: callData });
        // bytes32 entryPointUserOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
        //
        // // Validate userOperation
        // assertEq(userOpHash, entryPointUserOpHash);
    }

    function testWriteGas() public {
        string memory gasIdentifier = "testWriteGas";
        string memory rootDir = "gas_calculations";
        string memory fileName = string.concat(rootDir, "/", gasIdentifier, ".json");
        assertTrue(vm.isDir("gas_calculations"));
        if (vm.isFile(fileName)) {
            vm.removeFile(fileName);
        }
        assertFalse(vm.isFile(fileName));

        vm.setEnv("GAS", "true");

        instance.log4337Gas("testWriteGas");
        testexec__Given__TwoInputs();
        assertTrue(vm.isFile(fileName));
    }

    function testSimulateUserOp() public {
        writeSimulateUserOp(true);
        testexec__Given__TwoInputs();
    }
}
