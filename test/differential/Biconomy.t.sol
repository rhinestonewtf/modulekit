// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    RhinestoneModuleKitLib,
    RhinestoneAccount,
    UserOperation
} from "../../src/test/utils/biconomy-base/RhinestoneModuleKit.sol";
import { MockValidator } from "../../src/test/mocks/MockValidator.sol";
import { MockExecutor } from "../../src/test/mocks/MockExecutor.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

contract BiconomyDifferentialModuleKitLibTest is Test, RhinestoneModuleKit {
    using RhinestoneModuleKitLib for RhinestoneAccount;

    RhinestoneAccount instance;
    MockValidator validator;
    MockExecutor executor;

    MockERC20 token;

    function setUp() public {
        // Setup account
        instance = makeRhinestoneAccount("1");
        vm.deal(instance.account, 10 ether);

        // Setup modules
        validator = new MockValidator();
        executor = new MockExecutor();

        // Add modules to account
        instance.addValidator(address(validator));
        instance.addExecutor(address(executor));

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
        // @Todo: add signature
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
