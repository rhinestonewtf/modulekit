// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "src/ModuleKit.sol";
import "./BaseTest.t.sol";
import "src/Mocks.sol";
import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_FALLBACK,
    CALLTYPE_SINGLE
} from "src/external/ERC7579.sol";
import { getAccountType, InstalledModule } from "src/test/utils/Storage.sol";
import { toString } from "src/test/utils/Vm.sol";
import { AccountType } from "src/test/RhinestoneModuleKit.sol";

contract ERC7579DifferentialModuleKitLibTest is BaseTest {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    MockValidator internal validator;
    MockExecutor internal executor;
    MockFallback internal fallbackHandler;
    MockHook internal hook;
    MockTarget internal mockTarget;

    MockERC20 internal token;

    function setUp() public override {
        super.setUp();
        // Setup account
        instance = makeAccountInstance("account1");

        // Setup modules
        validator = new MockValidator();
        hook = new MockHook();
        executor = new MockExecutor();
        fallbackHandler = new MockFallback();
        mockTarget = new MockTarget();

        // Setup aux
        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);
        vm.deal(instance.account, 1000 ether);
    }

    function test_transfer() public {
        UserOpData memory data = instance.exec({ target: recipient, value: 1 ether, callData: "" });
        assertTrue(data.userOpHash != "");
        assertTrue(recipient.balance == 1 ether);
        assertTrue(data.userOp.sender == instance.account);
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
        // bytes memory signature = "";

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

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator,
            data: ""
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator1,
            data: ""
        });

        bool validatorEnabled = instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, newValidator);
        assertTrue(validatorEnabled);
        bool validator1Enabled = instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, newValidator1);
        assertTrue(validator1Enabled);
    }

    function test_getInstalledModules() public {
        address newValidator = address(new MockValidator());
        address newValidator1 = address(new MockValidator());
        vm.label(newValidator, "2nd validator");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator,
            data: ""
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator1,
            data: ""
        });

        InstalledModule[] memory modules = instance.getInstalledModules();
        assertTrue(modules.length == 2);
        assertTrue(
            modules[0].moduleAddress == newValidator && modules[1].moduleAddress == newValidator1
                && modules[0].moduleType == MODULE_TYPE_VALIDATOR
                && modules[1].moduleType == MODULE_TYPE_VALIDATOR
        );

        address newExecutor = address(new MockExecutor());
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: newExecutor, data: "" });
        modules = instance.getInstalledModules();

        assertTrue(modules.length == 3);
        assertTrue(
            modules[0].moduleAddress == newValidator && modules[1].moduleAddress == newValidator1
                && modules[2].moduleAddress == newExecutor
                && modules[0].moduleType == MODULE_TYPE_VALIDATOR
                && modules[1].moduleType == MODULE_TYPE_VALIDATOR
                && modules[2].moduleType == MODULE_TYPE_EXECUTOR
        );
    }

    function test_getInstalledModules_DifferentInstances() public {
        address newValidator = address(new MockValidator());
        address newValidator1 = address(new MockValidator());
        vm.label(newValidator, "2nd validator");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator,
            data: ""
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator1,
            data: ""
        });

        InstalledModule[] memory modules = instance.getInstalledModules();
        assertTrue(modules.length == 2);
        assertTrue(
            modules[0].moduleAddress == newValidator && modules[1].moduleAddress == newValidator1
                && modules[0].moduleType == MODULE_TYPE_VALIDATOR
                && modules[1].moduleType == MODULE_TYPE_VALIDATOR
        );

        address newExecutor = address(new MockExecutor());
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: newExecutor, data: "" });
        modules = instance.getInstalledModules();

        assertTrue(modules.length == 3);
        assertTrue(
            modules[0].moduleAddress == newValidator && modules[1].moduleAddress == newValidator1
                && modules[2].moduleAddress == newExecutor
                && modules[0].moduleType == MODULE_TYPE_VALIDATOR
                && modules[1].moduleType == MODULE_TYPE_VALIDATOR
                && modules[2].moduleType == MODULE_TYPE_EXECUTOR
        );

        // Deploy new instance using current env
        AccountInstance memory newInstance = makeAccountInstance("newSalt");
        assertTrue(newInstance.account.code.length == 0);
        newInstance.deployAccount();
        assertTrue(newInstance.account.code.length > 0);

        // Install modules on new instance
        newInstance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator,
            data: ""
        });
        newInstance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: newExecutor,
            data: ""
        });

        // Get installed modules on new instance
        InstalledModule[] memory newModules = newInstance.getInstalledModules();
        assertTrue(newModules.length == 2);
        assertTrue(
            newModules[0].moduleAddress == newValidator
                && newModules[1].moduleAddress == newExecutor
                && newModules[0].moduleType == MODULE_TYPE_VALIDATOR
                && newModules[1].moduleType == MODULE_TYPE_EXECUTOR
        );

        // Old instance modules should still be the same
        modules = instance.getInstalledModules();
        assertTrue(modules.length == 3);
        assertTrue(
            modules[0].moduleAddress == newValidator && modules[1].moduleAddress == newValidator1
                && modules[2].moduleAddress == newExecutor
                && modules[0].moduleType == MODULE_TYPE_VALIDATOR
                && modules[1].moduleType == MODULE_TYPE_VALIDATOR
                && modules[2].moduleType == MODULE_TYPE_EXECUTOR
        );
    }

    function test_getInstalledModules_AfterUninstall() public {
        address newValidator = address(new MockValidator());
        address newValidator1 = address(new MockValidator());
        vm.label(newValidator, "2nd validator");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator,
            data: ""
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator1,
            data: ""
        });

        InstalledModule[] memory modules = instance.getInstalledModules();
        assertTrue(modules.length == 2);
        assertTrue(
            modules[0].moduleAddress == newValidator && modules[1].moduleAddress == newValidator1
                && modules[0].moduleType == MODULE_TYPE_VALIDATOR
                && modules[1].moduleType == MODULE_TYPE_VALIDATOR
        );

        address newExecutor = address(new MockExecutor());
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: newExecutor, data: "" });
        modules = instance.getInstalledModules();

        assertTrue(modules.length == 3);
        assertTrue(
            modules[0].moduleAddress == newValidator && modules[1].moduleAddress == newValidator1
                && modules[2].moduleAddress == newExecutor
                && modules[0].moduleType == MODULE_TYPE_VALIDATOR
                && modules[1].moduleType == MODULE_TYPE_VALIDATOR
                && modules[2].moduleType == MODULE_TYPE_EXECUTOR
        );

        // Uninstall module
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator,
            data: ""
        });

        // Get installed modules
        modules = instance.getInstalledModules();

        assertTrue(modules.length == 2);
        assertTrue(
            modules[0].moduleAddress == newValidator1 && modules[1].moduleAddress == newExecutor
                && modules[0].moduleType == MODULE_TYPE_VALIDATOR
                && modules[1].moduleType == MODULE_TYPE_EXECUTOR
        );
    }

    function testRemoveValidator() public {
        address newValidator = address(new MockValidator());
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator,
            data: ""
        });
        bool validatorEnabled = instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, newValidator);
        assertTrue(validatorEnabled);

        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator,
            data: ""
        });
        validatorEnabled = instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, newValidator);
        assertFalse(validatorEnabled);
    }

    function testAddExecutor() public {
        address newExecutor = address(new MockExecutor());

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: newExecutor, data: "" });
        bool executorEnabled = instance.isModuleInstalled(MODULE_TYPE_EXECUTOR, newExecutor);
        assertTrue(executorEnabled);
    }

    function testRemoveExecutor() public {
        address newExecutor = address(new MockExecutor());

        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: newExecutor, data: "" });
        bool executorEnabled = instance.isModuleInstalled(MODULE_TYPE_EXECUTOR, newExecutor);
        assertTrue(executorEnabled);

        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: newExecutor,
            data: ""
        });
        executorEnabled = instance.isModuleInstalled(MODULE_TYPE_EXECUTOR, newExecutor);
        assertFalse(executorEnabled);
    }

    function testAddHook() public {
        instance.installModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(hook), data: "" });

        bool hookEnabled = instance.isModuleInstalled(MODULE_TYPE_HOOK, address(hook));
        assertTrue(hookEnabled);
    }

    function testRemoveHook() public {
        instance.installModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(hook), data: "" });

        bool hookEnabled = instance.isModuleInstalled(MODULE_TYPE_HOOK, address(hook));
        assertTrue(hookEnabled);

        instance.uninstallModule({ moduleTypeId: MODULE_TYPE_HOOK, module: address(hook), data: "" });
        hookEnabled = instance.isModuleInstalled(MODULE_TYPE_HOOK, address(hook));
        assertFalse(hookEnabled);
    }

    function testAddFallback() public {
        bytes memory fallbackData = abi.encode(bytes4(keccak256("foo()")), CALLTYPE_SINGLE, "");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_FALLBACK,
            module: address(fallbackHandler),
            data: fallbackData
        });

        bool fallbackEnabled =
            instance.isModuleInstalled(MODULE_TYPE_FALLBACK, address(fallbackHandler), fallbackData);
        assertTrue(fallbackEnabled);
    }

    function testRemoveFallback() public {
        bytes memory fallbackData = abi.encode(bytes4(keccak256("foo()")), CALLTYPE_SINGLE, "");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_FALLBACK,
            module: address(fallbackHandler),
            data: fallbackData
        });

        bool fallbackEnabled =
            instance.isModuleInstalled(MODULE_TYPE_FALLBACK, address(fallbackHandler), fallbackData);
        assertTrue(fallbackEnabled);

        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_FALLBACK,
            module: address(fallbackHandler),
            data: fallbackData
        });
        fallbackEnabled =
            instance.isModuleInstalled(MODULE_TYPE_FALLBACK, address(fallbackHandler), fallbackData);
        assertFalse(fallbackEnabled);
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
        UserOpData memory userOpData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(instance.defaultValidator)
        });
        bytes32 entryPointUserOpHash = instance.aux.entrypoint.getUserOpHash(userOpData.userOp);

        // Validate userOperation
        assertEq(userOpData.userOpHash, entryPointUserOpHash);
    }

    function testDeployAccount() public {
        AccountInstance memory newInstance = makeAccountInstance("new");
        assertTrue(newInstance.account.code.length == 0);

        newInstance.deployAccount();

        assertTrue(newInstance.account.code.length > 0);
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
        instance.simulateUserOp(true);
        testexec__Given__TwoInputs();
    }

    function testERC1271() public {
        bytes32 unformattedHash = keccak256("test");
        bytes32 hash =
            instance.formatERC1271Hash(address(instance.defaultValidator), unformattedHash);

        bool isValid = instance.isValidSignature({
            validator: address(instance.defaultValidator),
            hash: unformattedHash,
            signature: bytes("test")
        });
        assertTrue(isValid);
    }

    function testUsingAccountEnv() public {
        string[] memory envs = new string[](6);
        envs[0] = "DEFAULT";
        envs[1] = "SAFE";
        envs[2] = "KERNEL";
        envs[3] = "NEXUS";
        envs[4] = "CUSTOM";
        envs[5] = "INVALID";

        for (uint256 i = 0; i < envs.length; i++) {
            string memory env = envs[i];
            if (keccak256(abi.encodePacked(env)) == keccak256(abi.encodePacked("INVALID"))) {
                vm.expectRevert(ModuleKitHelpers.InvalidAccountType.selector);
                _usingAccountEnv(env);
            } else {
                _usingAccountEnv(env);
            }
        }
    }

    function testUsingAccountEnv_ModuleKitUninitialized() public {
        isInit = false;
        _usingAccountEnv("DEFAULT");
    }

    function testSetAccountEnv() public {
        // Deploy using current env
        AccountInstance memory oldEnvInstance = makeAccountInstance("sameSalt");
        assertTrue(oldEnvInstance.account.code.length == 0);
        oldEnvInstance.deployAccount();
        assertTrue(oldEnvInstance.account.code.length > 0);

        // Load env
        AccountType env = ModuleKitHelpers.getAccountType();

        // Switch env
        AccountType newEnv = env == AccountType.KERNEL ? AccountType.SAFE : AccountType.KERNEL;
        instance.setAccountEnv(newEnv.toString());

        // Deploy using new env
        AccountInstance memory newEnvInstance = makeAccountInstance("sameSalt");
        assertTrue(newEnvInstance.account.code.length == 0);
        newEnvInstance.deployAccount();
        assertTrue(newEnvInstance.account.code.length > 0);
    }

    function testSetAccountEnv_RevertsWhen_InvalidAccountType() public {
        vm.expectRevert(ModuleKitHelpers.InvalidAccountType.selector);
        instance.setAccountEnv("INVALID");
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _usingAccountEnv(string memory env) internal usingAccountEnv(env.toAccountType()) {
        AccountInstance memory newInstance = makeAccountInstance(keccak256(abi.encode(env)));
        assertTrue(newInstance.account.code.length == 0);

        newInstance.deployAccount();

        assertTrue(newInstance.account.code.length > 0);
    }
}
