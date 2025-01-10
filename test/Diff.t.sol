// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import "src/ModuleKit.sol";
import "./BaseTest.t.sol";
import "src/Mocks.sol";
import { ExecutionReturnData } from "src/test/RhinestoneModuleKit.sol";
import {
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_FALLBACK,
    VALIDATION_SUCCESS,
    VALIDATION_FAILED
} from "src/accounts/common/interfaces/IERC7579Module.sol";
import { CALLTYPE_SINGLE } from "src/accounts/common/lib/ModeLib.sol";
import { getAccountType, InstalledModule } from "src/test/utils/Storage.sol";
import { toString } from "src/test/utils/Vm.sol";
import { MockValidatorFalse } from "test/mocks/MockValidatorFalse.sol";
import { MockK1Validator, VALIDATION_SUCCESS } from "test/mocks/MockK1Validator.sol";
import { MockK1ValidatorUncompliantUninstall } from
    "test/mocks/MockK1ValidatorUncompliantUninstall.sol";
import { VmSafe } from "src/test/utils/Vm.sol";

contract ERC7579DifferentialModuleKitLibTest is BaseTest {
    using ModuleKitHelpers for *;

    MockValidator internal validator;
    MockValidatorFalse internal validatorFalse;
    MockExecutor internal executor;
    MockFallback internal fallbackHandler;
    MockHook internal hook;
    MockTarget internal mockTarget;

    MockERC20 internal token;
    address module;

    function setUp() public override {
        super.setUp();
        // Setup account
        instance = makeAccountInstance("account1");

        // Setup modules
        validator = new MockValidator();
        validatorFalse = new MockValidatorFalse();
        hook = new MockHook();
        executor = new MockExecutor();
        fallbackHandler = new MockFallback();
        mockTarget = new MockTarget();

        // Setup aux
        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);
        vm.deal(instance.account, 1000 ether);
        instance.simulateUserOp(false);
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
        ExecutionReturnData memory executionData = instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(instance.defaultValidator)
        }).execUserOps();

        // Validate Logs
        assertTrue(executionData.logs.length >= 5);

        // Validate userOperation
        assertEq(receiver.balance, value, "Receiver should have 10 gwei");
    }

    function testexec__RevertWhen__ValidationFails() public {
        // No revert reason
        _revertWhen__ValidationFails("");

        // Revert selector
        _revertWhen__ValidationFails(abi.encodePacked(bytes4(0x220266b6)));

        // Revert message
        _revertWhen__ValidationFails(
            abi.encodeWithSignature("FailedOp(uint256,string)", 0, "AA24 signature error")
        );
    }

    function testexec__RevertWhen__ValidationReverts() public {
        // No revert reason
        _revertWhen__ValidationReverts("");

        // Revert message
        bytes memory revertMessage;

        AccountType env = ModuleKitHelpers.getAccountType();

        // Revert selector
        _revertWhen__ValidationReverts(
            abi.encodePacked(bytes4(env == AccountType.SAFE ? 0xacfdb444 : 0x0))
        );

        if (env == AccountType.SAFE) {
            revertMessage = abi.encodePacked(bytes4(0xacfdb444));
        } else {
            revertMessage = abi.encodePacked(bytes4(0x0));
        }

        _revertWhen__ValidationReverts(revertMessage);
    }

    function testexec__RevertWhen__UserOperationFails() public {
        // Deploy the account first
        testexec__Given__TwoInputs();

        // No revert reason
        _revertWhen__UserOperationFails("");

        bytes memory revertSelector;
        bytes memory revertMessage;

        AccountType env = ModuleKitHelpers.getAccountType();
        if (env == AccountType.SAFE) {
            revertSelector = abi.encodePacked(bytes4(0xacfdb444));
            revertMessage = abi.encodePacked(bytes4(0xacfdb444));
        } else if (env == AccountType.KERNEL) {
            revertSelector = abi.encodePacked(bytes4(0xf21e646b));
            revertMessage = abi.encodePacked(bytes4(0xf21e646b));
        } else {
            revertSelector = abi.encodePacked(bytes4(0x82b42900));
            revertMessage = abi.encodePacked(bytes4(0x82b42900));
        }

        // Revert selector
        _revertWhen__UserOperationFails(revertSelector);

        // Revert message
        _revertWhen__UserOperationFails(revertMessage);
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

    function test_getInstalledModules() public whenEnvIsNotKernel {
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

        // Assert installed modules
        this._getModulesAndAssert(
            abi.encode(
                2, [newValidator, newValidator1], [MODULE_TYPE_VALIDATOR, MODULE_TYPE_VALIDATOR]
            ),
            instance
        );

        address newExecutor = address(new MockExecutor());
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: newExecutor, data: "" });

        // Assert installed modules
        this._getModulesAndAssert(
            abi.encode(
                3,
                [newValidator, newValidator1, newExecutor],
                [MODULE_TYPE_VALIDATOR, MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR]
            ),
            instance
        );
    }

    function test_getInstalledModules_DifferentInstances() public whenEnvIsNotKernel {
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

        // Assert installed modules
        this._getModulesAndAssert(
            abi.encode(
                2, [newValidator, newValidator1], [MODULE_TYPE_VALIDATOR, MODULE_TYPE_VALIDATOR]
            ),
            instance
        );

        address newExecutor = address(new MockExecutor());
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: newExecutor, data: "" });

        // Assert installed modules
        this._getModulesAndAssert(
            abi.encode(
                3,
                [newValidator, newValidator1, newExecutor],
                [MODULE_TYPE_VALIDATOR, MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR]
            ),
            instance
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

        // Assert installed modules on new instance
        this._getModulesAndAssert(
            abi.encode(
                2, [newValidator, newExecutor], [MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR]
            ),
            newInstance
        );

        // Old instance modules should still be the same
        this._getModulesAndAssert(
            abi.encode(
                3,
                [newValidator, newValidator1, newExecutor],
                [MODULE_TYPE_VALIDATOR, MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR]
            ),
            instance
        );
    }

    function test_getInstalledModules_AfterUninstall() public whenEnvIsNotKernel {
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

        // Assert installed modules
        this._getModulesAndAssert(
            abi.encode(
                2, [newValidator, newValidator1], [MODULE_TYPE_VALIDATOR, MODULE_TYPE_VALIDATOR]
            ),
            instance
        );

        address newExecutor = address(new MockExecutor());
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: newExecutor, data: "" });

        // Assert installed modules
        this._getModulesAndAssert(
            abi.encode(
                3, // length
                [newValidator, newValidator1, newExecutor], // expectedAddresses
                [MODULE_TYPE_VALIDATOR, MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR] // expectedTypes
            ),
            instance
        );

        // Uninstall module
        instance.uninstallModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidator,
            data: ""
        });

        // Assert installed modules
        this._getModulesAndAssert(
            abi.encode(
                2, [newValidator1, newExecutor], [MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR]
            ),
            instance
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
        isInit[block.chainid] = false;
        _usingAccountEnv("DEFAULT");
    }

    function testSetAccountEnv() public {
        // Deploy using current env
        AccountInstance memory oldEnvInstance = makeAccountInstance("sameSalt");
        assertTrue(oldEnvInstance.account.code.length == 0);
        oldEnvInstance.deployAccount();
        assertTrue(oldEnvInstance.account.code.length > 0);

        // Load env
        (bytes32 envHash) = getAccountType();

        // Switch env
        string memory newEnv = envHash == keccak256(abi.encodePacked("KERNEL")) ? "SAFE" : "KERNEL";
        instance.setAccountEnv(newEnv);

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
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _usingAccountEnv(string memory env) internal usingAccountEnv(env.toAccountType()) {
        AccountInstance memory newInstance = makeAccountInstance(keccak256(abi.encode(env)));
        assertTrue(newInstance.account.code.length == 0);

        newInstance.deployAccount();

        assertTrue(newInstance.account.code.length > 0);
    }

    function _getModulesAndAssert(
        bytes calldata expectedResultBytes,
        AccountInstance memory _instance
    )
        public
        view
    {
        InstalledModule[] memory modules = _instance.getInstalledModules();
        // Parse length
        uint256 length = abi.decode(expectedResultBytes[0:32], (uint256));
        // Parse addresses and types
        address[] memory expectedAddresses = new address[](length);
        uint256[] memory expectedTypes = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            expectedAddresses[i] =
                abi.decode(expectedResultBytes[32 + i * 32:64 + i * 32], (address));
            expectedTypes[i] = abi.decode(
                expectedResultBytes[32 + length * 32 + i * 32:64 + length * 32 + i * 32], (uint256)
            );
        }
        // Assert expected modules length
        assertTrue(
            modules.length == length + (instance.getAccountType() == AccountType.SAFE ? 1 : 0)
        );
        // AccountType.SAFE has 1 extra module added during setup, skip it
        uint256 index = instance.getAccountType() == AccountType.SAFE ? 1 : 0;
        for (uint256 i = 0; i < length; i++) {
            assertTrue(modules[index + i].moduleAddress == expectedAddresses[i]);
            assertTrue(modules[index + i].moduleType == expectedTypes[i]);
        }
    }

    function test_verifyModuleStorageWasCleared() public {
        // Set simulate mode to false
        instance.simulateUserOp(false);
        // Install a module
        module = address(new MockK1Validator());
        // Start state diff recording
        instance.startStateDiffRecording();
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: module,
            data: abi.encode(instance.account)
        });
        // Uninstall the module
        instance.uninstallModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: module, data: "" });
        // Stop state diff recording
        VmSafe.AccountAccess[] memory accountAccesses = instance.stopAndReturnStateDiff();
        // Assert that the module storage was cleared
        instance.verifyModuleStorageWasCleared(accountAccesses, module);
    }

    function test_verifyModuleStorageWasCleared_RevertsWhen_NotCleared_UsingComplianceFlag()
        public
    {
        // Set simulate mode to false
        instance.simulateUserOp(false);
        // Set compliance flag
        instance.storageCompliance(true);

        // Install a module
        module = address(new MockK1ValidatorUncompliantUninstall());
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: module,
            data: abi.encode(0xffffffffffffffffffff)
        });
        // Assert module storage
        assertEq(
            address(0xffffffffffffffffffff),
            MockK1Validator(module).smartAccountOwners(address(instance.account))
        );
        // Expect revert
        vm.expectRevert();
        this.__revertWhen_verifyModuleStorageWasCleared_NotCleared();
    }

    function test_verifyModuleStorageWasCleared_RevertsWhen_NotCleared() public {
        // Set simulate mode to false
        instance.simulateUserOp(false);
        // Install a module
        module = address(new MockK1ValidatorUncompliantUninstall());
        // Start state diff recording
        instance.startStateDiffRecording();
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: module,
            data: abi.encode(0xffffffffffffffffffff)
        });
        // Assert module storage
        assertEq(
            address(0xffffffffffffffffffff),
            MockK1Validator(module).smartAccountOwners(address(instance.account))
        );
        // Uninstall the module
        instance.uninstallModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: module, data: "" });
        // Stop state diff recording
        VmSafe.AccountAccess[] memory accountAccesses = instance.stopAndReturnStateDiff();
        // Expect revert
        vm.expectRevert();
        // Assert that the module storage was cleared
        instance.verifyModuleStorageWasCleared(accountAccesses, module);
    }

    function __revertWhen_verifyModuleStorageWasCleared_NotCleared() public {
        // Uninstall
        instance.uninstallModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: module, data: "" });
    }

    function test_withModuleStorageClearValidation()
        public
        withModuleStorageClearValidation(instance, module)
    {
        // Set simulate mode to false
        instance.simulateUserOp(false);
        // Install a module
        module = address(new MockK1Validator());
        // Install the module
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: module,
            data: abi.encode(VALIDATION_FAILED)
        });
        // Uninstall the module
        instance.uninstallModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: module, data: "" });
    }

    /*//////////////////////////////////////////////////////////////
                            EXPECT REVERT
    //////////////////////////////////////////////////////////////*/

    function _revertWhen__ValidationFails(bytes memory revertReason) public {
        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";

        if (!instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, address(validatorFalse))) {
            instance.installModule({
                moduleTypeId: MODULE_TYPE_VALIDATOR,
                module: address(validatorFalse),
                data: ""
            });
        }

        // Expect the revert
        if (revertReason.length == 0) {
            instance.expect4337Revert();
        } else if (revertReason.length == 4) {
            instance.expect4337Revert(bytes4(revertReason));
        } else {
            instance.expect4337Revert(revertReason);
        }

        // Create userOperation
        instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: address(validatorFalse)
        }).execUserOps();
    }

    function _revertWhen__ValidationReverts(bytes memory revertReason) public {
        address revertingValidator = makeAddr("revertingValidator");

        if (!instance.isModuleInstalled(MODULE_TYPE_VALIDATOR, revertingValidator)) {
            vm.etch(revertingValidator, address(validator).code);

            instance.installModule({
                moduleTypeId: MODULE_TYPE_VALIDATOR,
                module: revertingValidator,
                data: ""
            });

            vm.etch(revertingValidator, hex"fd");
        }

        // Create userOperation fields
        address receiver = makeAddr("receiver");
        uint256 value = 10 gwei;
        bytes memory callData = "";

        // Expect the revert
        if (revertReason.length == 0) {
            instance.expect4337Revert();
        } else if (revertReason.length == 4) {
            instance.expect4337Revert(bytes4(revertReason));
        } else {
            instance.expect4337Revert(revertReason);
        }

        // Create userOperation
        instance.getExecOps({
            target: receiver,
            value: value,
            callData: callData,
            txValidator: revertingValidator
        }).execUserOps();
    }

    function _revertWhen__UserOperationFails(bytes memory revertReason) public {
        // Create userOperation fields
        bytes memory callData = abi.encodeWithSelector(MockTarget.setAccessControl.selector, 2);

        // Expect the revert
        if (revertReason.length == 0) {
            instance.expect4337Revert();
        } else if (revertReason.length == 4) {
            instance.expect4337Revert(bytes4(revertReason));
        } else {
            instance.expect4337Revert(revertReason);
        }

        // Create userOperation
        instance.exec({ target: address(mockTarget), callData: callData, value: 0 });
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    // Used to skip tests when env is kernel as they don't emit events on module installation
    modifier whenEnvIsNotKernel() {
        AccountType env = ModuleKitHelpers.getAccountType();
        if (env == AccountType.KERNEL) {
            return;
        }
        _;
    }
}
