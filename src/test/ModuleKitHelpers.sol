// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Types
import {
    AccountInstance,
    UserOpData,
    ExecutionReturnData,
    AccountType,
    DEFAULT,
    SAFE,
    NEXUS,
    KERNEL,
    CUSTOM
} from "./RhinestoneModuleKit.sol";
import { PackedUserOperation } from "../external/ERC4337.sol";
import { MODULE_TYPE_HOOK } from "../accounts/common/interfaces/IERC7579Module.sol";
import { Execution } from "../accounts/erc7579/lib/ExecutionLib.sol";
import {
    Session,
    PermissionId,
    ActionData,
    PolicyData,
    ERC7739Data,
    ISessionValidator,
    SmartSessionMode,
    ISmartSession,
    EnableSession,
    ChainDigest
} from "../integrations/interfaces/ISmartSession.sol";
import { Solarray } from "solarray/Solarray.sol";

// Helpers
import { ERC4337Helpers } from "./utils/ERC4337Helpers.sol";
import { HelperBase } from "./helpers/HelperBase.sol";
import { KernelHelpers } from "./helpers/KernelHelpers.sol";

// Utils
import {
    prank,
    VmSafe,
    startStateDiffRecording as vmStartStateDiffRecording,
    stopAndReturnStateDiff as vmStopAndReturnStateDiff,
    getMappingKeyAndParentOf,
    envOr,
    setEnv
} from "./utils/Vm.sol";
import {
    getAccountType as getAccountTypeFromStorage,
    writeAccountType,
    writeExpectRevert,
    writeGasIdentifier,
    writeSimulateUserOp,
    writeStorageCompliance,
    getStorageCompliance,
    getSimulateUserOp,
    writeAccountEnv,
    getFactory,
    getHelper as getHelperFromStorage,
    getAccountEnv as getAccountEnvFromStorage,
    getInstalledModules as getInstalledModulesFromStorage,
    writeInstalledModule as writeInstalledModuleToStorage,
    removeInstalledModule as removeInstalledModuleFromStorage,
    InstalledModule
} from "./utils/Storage.sol";
import { recordLogs, VmSafe, getRecordedLogs } from "./utils/Vm.sol";

// Libraries
import { EncodeLib, HashLib } from "../test/helpers/SmartSessionHelpers.sol";

/// @notice A library that contains helper functions for building, testing, deploying, and
///         interacting with ERC7579 accounts and modules
library ModuleKitHelpers {
    /*//////////////////////////////////////////////////////////////////////////
                                      ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an invalid account type is provided, currently only DEFAULT, SAFE,
    ///         KERNEL, CUSTOM, and NEXUS are supported account types
    error InvalidAccountType();

    /// @notice Thrown when the smart sessions module is not installed
    error SmartSessionNotInstalled();

    /*//////////////////////////////////////////////////////////////////////////
                                    LIBRARIES
    //////////////////////////////////////////////////////////////////////////*/

    using ModuleKitHelpers for AccountInstance;
    using ModuleKitHelpers for UserOpData;
    using ModuleKitHelpers for AccountType;

    /*//////////////////////////////////////////////////////////////////////////
                                    EXECUTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Executes userOps on the entrypoint
    /// @param userOpData UserOpData struct containing the userOp, userOpHash, and entrypoint
    /// @return ExecutionReturnData struct containing the logs from the execution
    function execUserOps(UserOpData memory userOpData)
        internal
        returns (ExecutionReturnData memory)
    {
        // Send userOp to entrypoint
        return ERC4337Helpers.exec4337(userOpData.userOp, userOpData.entrypoint);
    }

    /// @notice Configures a userOp to execute a single operation
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param target The address of the contract to call
    /// @param value The amount of ether to send
    /// @param callData The data to send to the contract
    /// @param txValidator The address of the transaction validator
    /// @return userOpData UserOpData struct containing the userOp, userOpHash, and entrypoint
    function getExecOps(
        AccountInstance memory instance,
        address target,
        uint256 value,
        bytes memory callData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        bytes memory erc7579ExecCall =
            HelperBase(instance.accountHelper).encode(target, value, callData);
        (userOpData.userOp, userOpData.userOpHash) =
            HelperBase(instance.accountHelper).execUserOp(instance, erc7579ExecCall, txValidator);
        userOpData.entrypoint = instance.aux.entrypoint;
    }

    /// @notice Configures a userOp to execute multiple operations
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param executions An array of Execution structs containing the target, value, and callData
    /// @param txValidator The address of the transaction validator
    /// @return userOpData UserOpData struct containing the userOp, userOpHash, and entrypoint
    function getExecOps(
        AccountInstance memory instance,
        Execution[] memory executions,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        bytes memory erc7579ExecCall = HelperBase(instance.accountHelper).encode(executions);
        (userOpData.userOp, userOpData.userOpHash) =
            HelperBase(instance.accountHelper).execUserOp(instance, erc7579ExecCall, txValidator);
        userOpData.entrypoint = instance.aux.entrypoint;
    }

    /// @notice Configures a userOp to execute a single operation, signs it with the default
    ///         signature, and sends it to the entrypoint for execution
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param target The address of the contract to call
    /// @param value The amount of ether to send
    /// @param callData The data to send to the contract
    /// @return userOpData UserOpData struct containing the userOp, userOpHash, and entrypoint
    function exec(
        AccountInstance memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // Get userOpData
        userOpData =
            instance.getExecOps(target, value, callData, address(instance.defaultValidator));
        // Sign userOp with default signature
        userOpData = userOpData.signDefault();
        userOpData.entrypoint = instance.aux.entrypoint;
        // Send userOp to entrypoint
        userOpData.execUserOps();
    }

    /// @notice Executes a single operation on the entrypoint with value 0
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param target The address of the contract to call
    /// @param callData The data to send to the contract
    function exec(
        AccountInstance memory instance,
        address target,
        bytes memory callData
    )
        internal
        returns (UserOpData memory userOpData)
    {
        return exec(instance, target, 0, callData);
    }

    /*//////////////////////////////////////////////////////////////
                                 HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @notice A hook used to initiate state diff recording before installing a module
    function preEnvHook() internal {
        if (envOr("COMPLIANCE", false) || getStorageCompliance()) {
            // Start state diff recording
            vmStartStateDiffRecording();
        }
    }

    /// @notice A hook used to stop state diff recording and verify that storage was cleared after
    ///         uninstalling a module
    function postEnvHook(AccountInstance memory instance, bytes memory data) internal {
        if (envOr("COMPLIANCE", false) || getStorageCompliance()) {
            address module = abi.decode(data, (address));
            // Stop state diff recording and return account accesses
            VmSafe.AccountAccess[] memory accountAccesses = vmStopAndReturnStateDiff();
            // Check if storage was cleared
            verifyModuleStorageWasCleared(instance, accountAccesses, module);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODULE CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Installs a module on an account by generating a userOp and sending it to the
    ///         entrypoint
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param moduleTypeId The type of the module to install
    /// @param module The address of the module to install
    /// @param data Arbitrary data that may be required on the module during `onInstall`
    ///         initialization
    /// @return userOpData UserOpData struct containing the userOp, userOpHash, and entrypoint
    function installModule(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // Run preEnvHook
        preEnvHook();
        userOpData = instance.getInstallModuleOps(
            moduleTypeId, module, data, address(instance.defaultValidator)
        );
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        userOpData.entrypoint = instance.aux.entrypoint;
        // send userOp to entrypoint
        userOpData.execUserOps();
    }

    /// @notice Uninstalls a module on an account by generating a userOp and sending it to the
    ///         entrypoint
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param moduleTypeId The type of the module to uninstall
    /// @param module The address of the module to uninstall
    /// @param data Arbitrary data that may be required on the module during `onUninstall`
    ///         de-initialization
    /// @return userOpData UserOpData struct containing the userOp, userOpHash, and entrypoint
    function uninstallModule(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.getUninstallModuleOps(
            moduleTypeId, module, data, address(instance.defaultValidator)
        );
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        userOpData.entrypoint = instance.aux.entrypoint;

        // send userOp to entrypoint
        userOpData.execUserOps();
        // Run postEnvHook
        postEnvHook(instance, abi.encode(module));
    }

    /// @notice Checks if a module is installed on an account
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param moduleTypeId The type of the module to check
    /// @param module The address of the module to check
    /// @return bool True if the module is installed, false otherwise
    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module
    )
        internal
        returns (bool)
    {
        return instance.account.code.length > 0
            && HelperBase(instance.accountHelper).isModuleInstalled(instance, moduleTypeId, module);
    }

    /// @notice Checks if a module is installed on an account by using additional data
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param moduleTypeId The type of the module to check
    /// @param module The address of the module to check
    /// @param data Arbitrary data that may be required
    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        returns (bool)
    {
        return HelperBase(instance.accountHelper).isModuleInstalled(
            instance, moduleTypeId, module, data
        );
    }

    /// @notice Gets the data required to install a module
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param moduleTypeId The type of the module to install
    /// @param module The address of the module to install
    /// @param data Arbitrary data that may be required on the module during `onInstall`
    ///         initialization
    /// @return bytes The data required to install the module
    function getInstallModuleData(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        view
        returns (bytes memory)
    {
        return HelperBase(instance.accountHelper).getInstallModuleData(
            instance, moduleTypeId, module, data
        );
    }

    /// @notice Gets the data required to uninstall a module
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param moduleTypeId The type of the module to uninstall
    /// @param module The address of the module to uninstall
    /// @param data Arbitrary data that may be required on the module during `onUninstall`
    ///         de-initialization
    /// @return bytes The data required to uninstall the module
    function getUninstallModuleData(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        view
        returns (bytes memory)
    {
        return HelperBase(instance.accountHelper).getUninstallModuleData(
            instance, moduleTypeId, module, data
        );
    }

    /// @notice Generates a userOp to install a module on an account
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param module The address of the module to install
    /// @param initData Arbitrary data that may be required on the module during `onInstall`
    ///         initialization
    /// @param txValidator The address of the transaction validator
    /// @return userOpData UserOpData struct containing the userOp, userOpHash, and entrypoint
    function getInstallModuleOps(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = HelperBase(instance.accountHelper)
            .configModuleUserOp(instance, moduleType, module, initData, true, txValidator);
        userOpData.entrypoint = instance.aux.entrypoint;
    }

    /// @notice Generates a userOp to uninstall a module on an account
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param module The address of the module to uninstall
    /// @param initData Arbitrary data that may be required on the module during `onUninstall`
    ///         de-initialization
    /// @param txValidator The address of the transaction validator
    /// @return userOpData UserOpData struct containing the userOp, userOpHash, and entrypoint
    function getUninstallModuleOps(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // get userOp with correct nonce for selected txValidator
        (userOpData.userOp, userOpData.userOpHash) = HelperBase(instance.accountHelper)
            .configModuleUserOp(instance, moduleType, module, initData, false, txValidator);
        userOpData.entrypoint = instance.aux.entrypoint;
    }

    /// @notice Gets all installed modules on an account
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @return InstalledModule[] An array of InstalledModule structs containing the module type and
    ///         address
    function getInstalledModules(AccountInstance memory instance)
        internal
        view
        returns (InstalledModule[] memory)
    {
        return getInstalledModulesFromStorage(instance.account);
    }

    /// @notice Writes an installed module struct data to storage
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param module InstalledModule struct containing the module type and address
    function writeInstalledModule(
        AccountInstance memory instance,
        InstalledModule memory module
    )
        internal
    {
        writeInstalledModuleToStorage(module, instance.account);
    }

    /// @notice Removes an installed module from storage
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param moduleType The type of the module to remove
    /// @param moduleAddress The address of the module to remove
    function removeInstalledModule(
        AccountInstance memory instance,
        uint256 moduleType,
        address moduleAddress
    )
        internal
    {
        // Get installed modules for account
        InstalledModule[] memory installedModules = getInstalledModules(instance);
        // Find module to remove (not super scalable at high module counts)
        for (uint256 i; i < installedModules.length; i++) {
            if (
                installedModules[i].moduleType == moduleType
                    && installedModules[i].moduleAddress == moduleAddress
            ) {
                // Remove module from storage
                removeInstalledModuleFromStorage(i, instance.account);
                return;
            }
        }
    }

    /// @notice Starts recording the state diff
    function startStateDiffRecording(AccountInstance memory) internal {
        vmStartStateDiffRecording();
    }

    /// @notice Stop recording the state diff and return the account accesses
    /// @return VmSafe.AccountAccess[] An array of AccountAccess structs containing the account
    function stopAndReturnStateDiff(AccountInstance memory)
        internal
        returns (VmSafe.AccountAccess[] memory)
    {
        return vmStopAndReturnStateDiff();
    }

    /// @notice Verifies from an accountAccesses array that storage was correctly cleared after
    ///         uninstalling a module, reverts if storage was not cleared correctly
    /// @param accountAccesses An array of AccountAccess structs containing the account
    /// @param module The address of the module to check
    function verifyModuleStorageWasCleared(
        AccountInstance memory,
        VmSafe.AccountAccess[] memory accountAccesses,
        address module
    )
        internal
        view
    {
        bytes32[] memory seenSlots = new bytes32[](1000);
        bytes32[] memory finalValues = new bytes32[](1000);
        uint256 numSlots;

        // Loop through account accesses
        for (uint256 i; i < accountAccesses.length; i++) {
            // Skip tests
            if (accountAccesses[i].accessor == address(this)) {
                continue;
            }

            // If we are accessing the storage of the module check writes and clears
            if (accountAccesses[i].account == module) {
                // Process all storage accesses for this module
                for (uint256 j; j < accountAccesses[i].storageAccesses.length; j++) {
                    VmSafe.StorageAccess memory access = accountAccesses[i].storageAccesses[j];

                    // Skip reads
                    if (!access.isWrite) {
                        continue;
                    }

                    // Find if we've seen this slot
                    bool found;
                    for (uint256 k; k < numSlots; k++) {
                        if (seenSlots[k] == access.slot) {
                            finalValues[k] = access.newValue;
                            found = true;
                            break;
                        }
                    }

                    // If not seen, add it
                    if (!found) {
                        seenSlots[numSlots] = access.slot;
                        finalValues[numSlots] = access.newValue;
                        numSlots++;
                    }
                }
            }
        }

        // Check if any slot's final value is non-zero
        for (uint256 i; i < numSlots; i++) {
            if (finalValues[i] != bytes32(0)) {
                revert("Storage not cleared after uninstalling module");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                CONTROL FLOW
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Sets the expect revert flag to true
    function expect4337Revert(AccountInstance memory) internal {
        writeExpectRevert("");
    }

    /// @notice Sets the expect revert flag to true for a given selector
    /// @param selector The selector of the function that is expected to revert
    function expect4337Revert(AccountInstance memory, bytes4 selector) internal {
        writeExpectRevert(abi.encodePacked(selector));
    }

    /// @notice Sets the expect revert flag to true for a given message
    /// @param message The message that is expected to revert
    function expect4337Revert(AccountInstance memory, bytes memory message) internal {
        writeExpectRevert(message);
    }

    /// @notice Logs the gas used by an ERC-4337 transaction
    /// @dev needs to be called before an exec4337 call
    /// @dev the id needs to be unique across your tests, otherwise the gas calculations will
    ///      overwrite each other
    /// @param id Identifier for the gas calculation, which will be used as the filename
    function log4337Gas(AccountInstance memory, /* instance */ string memory id) internal {
        writeGasIdentifier(id);
    }

    /// @notice Writes the simulate user op flag to storage
    /// @param value The value to write to storage (true or false)
    function simulateUserOp(AccountInstance memory, bool value) internal {
        writeSimulateUserOp(value);
        string memory strValue = value ? "true" : "false";
        setEnv("SIMULATE", strValue);
    }

    /// @notice Writes the storage compliance flag to storage
    /// @param value The value to write to storage (true or false)
    function storageCompliance(AccountInstance memory, bool value) internal {
        writeStorageCompliance(value);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ACCOUNT UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Converts an AccountType enum to a string
    /// @param _accountType The AccountType enum to convert
    /// @return accountType The string representation of the AccountType
    function toString(AccountType _accountType) internal pure returns (string memory accountType) {
        if (_accountType == AccountType.DEFAULT) {
            return DEFAULT;
        } else if (_accountType == AccountType.SAFE) {
            return SAFE;
        } else if (_accountType == AccountType.KERNEL) {
            return KERNEL;
        } else if (_accountType == AccountType.CUSTOM) {
            return CUSTOM;
        } else if (_accountType == AccountType.NEXUS) {
            return NEXUS;
        } else {
            revert InvalidAccountType();
        }
    }

    /// @notice Converts a string to an AccountType enum
    /// @param _accountType The string to convert
    /// @return accountType The AccountType enum
    function toAccountType(string memory _accountType)
        internal
        pure
        returns (AccountType accountType)
    {
        if (keccak256(abi.encodePacked(_accountType)) == keccak256(abi.encodePacked(DEFAULT))) {
            return AccountType.DEFAULT;
        } else if (keccak256(abi.encodePacked(_accountType)) == keccak256(abi.encodePacked(SAFE))) {
            return AccountType.SAFE;
        } else if (keccak256(abi.encodePacked(_accountType)) == keccak256(abi.encodePacked(KERNEL)))
        {
            return AccountType.KERNEL;
        } else if (keccak256(abi.encodePacked(_accountType)) == keccak256(abi.encodePacked(CUSTOM)))
        {
            return AccountType.CUSTOM;
        } else if (keccak256(abi.encodePacked(_accountType)) == keccak256(abi.encodePacked(NEXUS)))
        {
            return AccountType.NEXUS;
        } else {
            revert InvalidAccountType();
        }
    }

    /// @notice Deploys an account, writes installed modules to storage from recorded logs
    /// @param instance AccountInstance struct containing the account and accountHelper
    function deployAccount(AccountInstance memory instance) internal {
        // Record logs to track installed modules
        recordLogs();
        // Deploy account
        HelperBase(instance.accountHelper).deployAccount(instance);
        // Parse logs and determine if a module was installed
        VmSafe.Log[] memory logs = getRecordedLogs();
        for (uint256 i; i < logs.length; i++) {
            // ModuleInstalled(uint256, address)
            if (
                logs[i].topics[0]
                    == 0xd21d0b289f126c4b473ea641963e766833c2f13866e4ff480abd787c100ef123
            ) {
                (uint256 moduleType, address module) = abi.decode(logs[i].data, (uint256, address));
                writeInstalledModuleToStorage(InstalledModule(moduleType, module), logs[i].emitter);
            }
        }
    }

    /// @notice Sets the account type in storage
    /// @param env The AccountType enum to set
    function setAccountType(AccountInstance memory, AccountType env) internal {
        setAccountType(env);
    }

    /// @notice Sets the account type in storage
    /// @param env The AccountType enum to set
    function setAccountType(AccountType env) internal {
        writeAccountType(env.toString());
    }

    /// @notice Sets the account type in storage from a string
    /// @param env The string to set
    function setAccountEnv(AccountInstance memory, string memory env) internal {
        setAccountEnv(env);
    }

    /// @notice Sets the account type in storage from a string
    /// @param env The string to set
    function setAccountEnv(string memory env) internal {
        _setAccountEnv(env);
    }

    /// @notice Sets the account type in storage from an enum
    /// @param env The AccountType enum to set
    function setAccountEnv(AccountType env) internal {
        _setAccountEnv(env.toString());
    }

    /// @notice Gets the account type from storage
    /// @return accountType The account type
    function getAccountType() internal view returns (AccountType accountType) {
        bytes32 accountTypeHash = getAccountTypeFromStorage();
        if (accountTypeHash == keccak256(abi.encodePacked(DEFAULT))) {
            return AccountType.DEFAULT;
        } else if (accountTypeHash == keccak256(abi.encodePacked(SAFE))) {
            return AccountType.SAFE;
        } else if (accountTypeHash == keccak256(abi.encodePacked(KERNEL))) {
            return AccountType.KERNEL;
        } else if (accountTypeHash == keccak256(abi.encodePacked(CUSTOM))) {
            return AccountType.CUSTOM;
        } else if (accountTypeHash == keccak256(abi.encodePacked(NEXUS))) {
            return AccountType.NEXUS;
        } else {
            revert InvalidAccountType();
        }
    }

    /// @notice Gets the account type from storage for an AccountInstance
    function getAccountType(AccountInstance memory)
        internal
        view
        returns (AccountType accountType)
    {
        return getAccountType();
    }

    /// @notice Sets the account type in storage from a string
    function _setAccountEnv(string memory env) private {
        address factory = getFactory(env);
        address helper = getHelperFromStorage(env);
        if (keccak256(abi.encodePacked(env)) == keccak256(abi.encodePacked(DEFAULT))) {
            writeAccountEnv(env, factory, helper);
        } else if (keccak256(abi.encodePacked(env)) == keccak256(abi.encodePacked(SAFE))) {
            writeAccountEnv(env, factory, helper);
        } else if (keccak256(abi.encodePacked(env)) == keccak256(abi.encodePacked(KERNEL))) {
            writeAccountEnv(env, factory, helper);
        } else if (keccak256(abi.encodePacked(env)) == keccak256(abi.encodePacked(CUSTOM))) {
            writeAccountEnv(env, factory, helper);
        } else if (keccak256(abi.encodePacked(env)) == keccak256(abi.encodePacked(NEXUS))) {
            writeAccountEnv(env, factory, helper);
        } else {
            revert InvalidAccountType();
        }
    }

    /// @notice Gets the account environment from storage
    function getAccountEnv() internal view returns (AccountType env, address, address) {
        (bytes32 envHash, address factory, address helper) = getAccountEnvFromStorage();
        if (envHash == keccak256(abi.encodePacked(DEFAULT))) {
            return (AccountType.DEFAULT, factory, helper);
        } else if (envHash == keccak256(abi.encodePacked(SAFE))) {
            return (AccountType.SAFE, factory, helper);
        } else if (envHash == keccak256(abi.encodePacked(KERNEL))) {
            return (AccountType.KERNEL, factory, helper);
        } else if (envHash == keccak256(abi.encodePacked(CUSTOM))) {
            return (AccountType.CUSTOM, factory, helper);
        } else if (envHash == keccak256(abi.encodePacked(NEXUS))) {
            return (AccountType.NEXUS, factory, helper);
        } else {
            revert InvalidAccountType();
        }
    }

    /// @notice Gets the account environment from storage for an AccountInstance
    function getAccountEnv(AccountInstance memory)
        internal
        view
        returns (AccountType env, address, address)
    {
        return getAccountEnv();
    }

    /// @notice Gets the helper from storage for an AccountType
    /// @param env The AccountType enum to get the helper for
    /// @return address The address of the helper
    function getHelper(AccountType env) internal view returns (address) {
        if (env == AccountType.DEFAULT) {
            return getHelperFromStorage(DEFAULT);
        } else if (env == AccountType.SAFE) {
            return getHelperFromStorage(SAFE);
        } else if (env == AccountType.KERNEL) {
            return getHelperFromStorage(KERNEL);
        } else if (env == AccountType.CUSTOM) {
            return getHelperFromStorage(CUSTOM);
        } else if (env == AccountType.NEXUS) {
            return getHelperFromStorage(NEXUS);
        } else {
            revert InvalidAccountType();
        }
    }

    /// @dev Used to deploy an account if it has not been deployed
    modifier withAccountDeployed(AccountInstance memory instance) {
        if (instance.account.code.length == 0) {
            deployAccount(instance);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SIGNATURE UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks if a signature is valid by calling the accountHelper of the account instance
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param validator The address of the validator
    /// @param hash The hash to validate
    /// @param signature The signature to validate
    /// @return bool True if the signature is valid, false otherwise
    function isValidSignature(
        AccountInstance memory instance,
        address validator,
        bytes32 hash,
        bytes memory signature
    )
        internal
        returns (bool)
    {
        return HelperBase(instance.accountHelper).isValidSignature(
            instance, validator, hash, signature
        );
    }

    /// @notice Formats a hash for ERC-1271 validation by calling the accountHelper of the account
    ///         instance
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param validator The address of the validator
    /// @param hash The hash to format
    /// @return bytes32 The formatted hash
    function formatERC1271Hash(
        AccountInstance memory instance,
        address validator,
        bytes32 hash
    )
        internal
        returns (bytes32)
    {
        return HelperBase(instance.accountHelper).formatERC1271Hash(instance, validator, hash);
    }

    /// @notice Formats a signature for ERC-1271 validation by calling the accountHelper of the
    ///         account instance
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param validator The address of the validator
    /// @param signature The signature to format
    /// @return bytes The formatted signature
    function formatERC1271Signature(
        AccountInstance memory instance,
        address validator,
        bytes memory signature
    )
        internal
        returns (bytes memory)
    {
        return HelperBase(instance.accountHelper).formatERC1271Signature(
            instance, validator, signature
        );
    }

    /// @notice Adds a default signature to a UserOpData struct
    /// @param userOpData UserOpData struct with the default signature added
    function signDefault(UserOpData memory userOpData) internal pure returns (UserOpData memory) {
        userOpData.userOp.signature = "DEFAULT SIGNATURE";
        return userOpData;
    }

    /// @notice Signs a hash with a default signature
    /// @param hash The hash to sign
    /// @return bytes The signature
    function ecdsaSignDefault(bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = (27, hash, hash);
        return abi.encodePacked(r, s, v);
    }

    /*//////////////////////////////////////////////////////////////
                             SMART SESSIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Makes sure the smart sessions module is installed
    modifier withSmartSessionsInstalled(AccountInstance memory instance) {
        if (!instance.isModuleInstalled(1, address(instance.smartSession))) {
            revert SmartSessionNotInstalled();
        }
        _;
    }

    /// @notice Adds a session to the account with the default validator
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param session The session to add
    function addSession(
        AccountInstance memory instance,
        Session memory session
    )
        internal
        withAccountDeployed(instance)
        returns (PermissionId permissionIds)
    {
        // Check if smart sessions module is already installed
        if (!instance.isModuleInstalled(1, address(instance.smartSession))) {
            // Install smart sessions module
            instance.installModule(1, address(instance.smartSession), "");
        }
        // Enable session
        Session[] memory sessions = new Session[](1);
        sessions[0] = session;
        prank(instance.account);
        permissionIds = instance.smartSession.enableSessions(sessions)[0];
    }

    /// @notice Adds a session to the account with the default validator
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param salt The salt to use for the session
    /// @param userOpPolicies The user operation policies to use for the session
    /// @param erc7739Policy The ERC-7739 policy to use for the session
    /// @param actionDatas The action datas to use for the session
    /// @return permissionIds The permission id of the Session
    function addSession(
        AccountInstance memory instance,
        bytes32 salt,
        PolicyData[] memory userOpPolicies,
        ERC7739Data memory erc7739Policy,
        ActionData[] memory actionDatas
    )
        internal
        withAccountDeployed(instance)
        returns (PermissionId permissionIds)
    {
        // Check if smart sessions module is already installed
        if (!instance.isModuleInstalled(1, address(instance.smartSession))) {
            // Install smart sessions module
            instance.installModule(1, address(instance.smartSession), "");
        }
        // Setup session data
        Session memory session = Session(
            ISessionValidator(address(instance.defaultSessionValidator)),
            "mockInitData",
            salt,
            userOpPolicies,
            erc7739Policy,
            actionDatas
        );
        // Enable session
        return instance.addSession(session);
    }

    /// @notice Removes a session from the account
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param permissionId The permission id of the session to remove
    function removeSession(
        AccountInstance memory instance,
        PermissionId permissionId
    )
        internal
        withAccountDeployed(instance)
        withSmartSessionsInstalled(instance)
    {
        // Remove session
        prank(instance.account);
        instance.smartSession.removeSession(permissionId);
    }

    /// @notice Checks if a permission is enabled
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param permissionId The permission id to check
    /// @return bool True if the permission is enabled, false otherwise
    function isPermissionEnabled(
        AccountInstance memory instance,
        PermissionId permissionId
    )
        internal
        withAccountDeployed(instance)
        withSmartSessionsInstalled(instance)
        returns (bool)
    {
        // Check if session is enabled
        return instance.smartSession.isPermissionEnabled(permissionId, instance.account);
    }

    /// @notice Gets the permission id of a session
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param session The session to get the permission id of
    /// @return permissionId The permission id of the session
    function getPermissionId(
        AccountInstance memory instance,
        Session memory session
    )
        internal
        withSmartSessionsInstalled(instance)
        returns (PermissionId permissionId)
    {
        // Check if smart sessions module is installed
        if (!instance.isModuleInstalled(1, address(instance.smartSession))) {
            revert SmartSessionNotInstalled();
        }
        return instance.smartSession.getPermissionId(session);
    }

    /// @notice Gets the session digest
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param session The session to get the digest of
    /// @param mode The SmartSessionMode to use
    /// @return bytes32 The session digest
    function getSessionDigest(
        AccountInstance memory instance,
        Session memory session,
        SmartSessionMode mode
    )
        internal
        withSmartSessionsInstalled(instance)
        returns (bytes32)
    {
        return instance.smartSession.getSessionDigest(
            getPermissionId(instance, session), instance.account, session, mode
        );
    }

    /// @notice Gets the session nonce
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param permissionId The permission id of the session to get the nonce of
    /// @return uint256 The session nonce
    function getSessionNonce(
        AccountInstance memory instance,
        PermissionId permissionId
    )
        internal
        withSmartSessionsInstalled(instance)
        returns (uint256)
    {
        return instance.smartSession.getNonce(permissionId, instance.account);
    }

    /// @notice Encodes a signature for a user operation using the correct format
    /// @param instance AccountInstance struct
    /// @param userOperation The user operation to encode the signature for
    /// @param mode The SmartSessionMode to use
    /// @param session The session to use
    /// @return bytes The encoded signature
    function encodeSignature(
        AccountInstance memory instance,
        PackedUserOperation memory userOperation,
        SmartSessionMode mode,
        Session memory session
    )
        internal
        returns (bytes memory)
    {
        // Get permission id
        PermissionId permissionId = getPermissionId(instance, session);
        // Encode based on mode
        if (mode == SmartSessionMode.USE) {
            return EncodeLib.encodeUse(permissionId, userOperation.signature);
        } else {
            revert("Missing signFunction and validator params");
        }
    }

    /// @notice Encodes the signature for a user operation using the correct format and passed
    /// signing function and validator
    /// @param instance AccountInstance struct
    /// @param userOperation The user operation to encode the signature for
    /// @param mode The SmartSessionMode to use
    /// @param session The session to use
    /// @param signFunction The signing function to use
    /// @param validator The validator to use
    /// @return bytes The encoded signature
    function encodeSignature(
        AccountInstance memory instance,
        PackedUserOperation memory userOperation,
        SmartSessionMode mode,
        Session memory session,
        function (bytes32) internal returns (bytes memory) signFunction,
        address validator
    )
        internal
        returns (bytes memory)
    {
        // Get permission id
        PermissionId permissionId = getPermissionId(instance, session);
        // Encode based on mode
        if (mode == SmartSessionMode.USE) {
            return EncodeLib.encodeUse(permissionId, userOperation.signature);
        } else {
            // Create enable session data
            EnableSession memory enableData = makeMultiChainEnableData(instance, session, mode);
            // Get the hash
            bytes32 hash = HashLib.multichainDigest(enableData.hashesAndChainIds);
            // Sign the enable hash
            enableData.permissionEnableSig = abi.encodePacked(validator, signFunction(hash));
            // Encode based on mode
            if (mode == SmartSessionMode.UNSAFE_ENABLE) {
                return EncodeLib.encodeUnsafeEnable(userOperation.signature, enableData);
            } else {
                return EncodeLib.encodeEnable(userOperation.signature, enableData);
            }
        }
    }

    /// @notice Encodes the signature for a user operation using the USE mode
    /// @param instance AccountInstance struct
    /// @param userOperation The user operation to encode the signature for
    /// @param session The session to use
    /// @return bytes The encoded signature
    function encodeSignatureUseMode(
        AccountInstance memory instance,
        PackedUserOperation memory userOperation,
        Session memory session
    )
        internal
        returns (bytes memory)
    {
        return instance.encodeSignature(
            userOperation,
            SmartSessionMode.USE,
            session,
            ecdsaSignDefault, // Irrelevant in use mode
            address(0) // Irrelevant in use mode
        );
    }

    /// @notice Encodes the signature for a user operation using the ENABLE mode
    /// @param instance AccountInstance struct
    /// @param userOperation The user operation to encode the signature for
    /// @param session The session to use
    /// @param signFunction The signing function to use
    /// @param validator The validator to use
    /// @return bytes The encoded signature
    function encodeSignatureEnableMode(
        AccountInstance memory instance,
        PackedUserOperation memory userOperation,
        Session memory session,
        function (bytes32) internal returns (bytes memory) signFunction,
        address validator
    )
        internal
        returns (bytes memory)
    {
        return instance.encodeSignature(
            userOperation, SmartSessionMode.ENABLE, session, signFunction, validator
        );
    }

    /// @notice Encodes the signature for a user operation using the UNSAFE_ENABLE mode
    /// @param instance AccountInstance struct
    /// @param userOperation The user operation to encode the signature for
    /// @param session The session to use
    /// @param signFunction The signing function to use
    /// @param validator The validator to use
    /// @return bytes The encoded signature
    function encodeSignatureUnsafeEnableMode(
        AccountInstance memory instance,
        PackedUserOperation memory userOperation,
        Session memory session,
        function (bytes32) internal returns (bytes memory) signFunction,
        address validator
    )
        internal
        returns (bytes memory)
    {
        return instance.encodeSignature(
            userOperation, SmartSessionMode.UNSAFE_ENABLE, session, signFunction, validator
        );
    }

    /// @notice Checks if a session is enabled
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param session The session to check
    /// @return bool True if the session is enabled, false otherwise
    function isSessionEnabled(
        AccountInstance memory instance,
        Session memory session
    )
        internal
        withSmartSessionsInstalled(instance)
        returns (bool)
    {
        // Get permission id
        PermissionId permissionId = getPermissionId(instance, session);
        return instance.smartSession.isISessionValidatorSet(permissionId, instance.account)
            && instance.smartSession.areUserOpPoliciesEnabled(
                instance.account, permissionId, session.userOpPolicies
            )
            && instance.smartSession.areActionsEnabled(instance.account, permissionId, session.actions)
            && instance.smartSession.areERC1271PoliciesEnabled(
                instance.account, permissionId, session.erc7739Policies.erc1271Policies
            );
    }

    /// @dev Kernel requires us to temporarily disable the hook multiplexer to use smart sessions
    modifier withHookFixForKernel(AccountInstance memory instance) {
        // Check if account is KERNEL
        if (instance.accountType == AccountType.KERNEL) {
            // Cache hook multiplexer
            address hookMultiplexer =
                KernelHelpers(instance.accountHelper).getHookMultiPlexer(instance);
            // Uninstall MockHookMultiplexer
            instance.uninstallModule(MODULE_TYPE_HOOK, hookMultiplexer, "");
            // Set hook multiplexer to address(1)
            KernelHelpers(instance.accountHelper).setHookMultiPlexer(instance, address(1));
            _;
            // Set hook multiplexer back to MockHookMultiplexer
            KernelHelpers(instance.accountHelper).setHookMultiPlexer(instance, hookMultiplexer);
            // Reinstall MockHookMultiplexer
            instance.installModule(MODULE_TYPE_HOOK, hookMultiplexer, "");
        } else {
            _;
        }
    }

    /// @notice Uses a session to execute a user operation
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param session The session to use
    /// @param target The target address of the user operation
    /// @param value The value of the user operation
    /// @param callData The call data of the user operation
    function useSession(
        AccountInstance memory instance,
        Session memory session,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        withHookFixForKernel(instance)
    {
        // Check if smart sessions module is already installed
        if (!instance.isModuleInstalled(1, address(instance.smartSession))) {
            // Install smart sessions module
            instance.installModule(1, address(instance.smartSession), "");
        }

        // Get user ops
        UserOpData memory userOpData =
            instance.getExecOps(target, value, callData, address(instance.smartSession));

        // Get permission id
        PermissionId permissionId = getPermissionId(instance, session);

        // Check if session is enabled and enable if not
        if (!isSessionEnabled(instance, session)) {
            prank(instance.account);
            Session[] memory sessions = new Session[](1);
            sessions[0] = session;
            instance.smartSession.enableSessions(sessions);
        }

        // Sign user op
        userOpData.userOp.signature = EncodeLib.encodeUse(permissionId, userOpData.userOp.signature);

        // Execute user op
        userOpData.execUserOps();
    }

    /// @notice Uses a session to execute a batch of user operations
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param session The session to use
    /// @param executions The executions to execute
    function useSession(
        AccountInstance memory instance,
        Session memory session,
        Execution[] memory executions
    )
        internal
        withHookFixForKernel(instance)
    {
        // Check if smart sessions module is already installed
        if (!instance.isModuleInstalled(1, address(instance.smartSession))) {
            // Install smart sessions module
            instance.installModule(1, address(instance.smartSession), "");
        }

        // Get user ops for multiple executions
        UserOpData memory userOpData =
            instance.getExecOps(executions, address(instance.smartSession));

        // Get permission id
        PermissionId permissionId = getPermissionId(instance, session);

        // Check if session is enabled and enable if not
        if (!isSessionEnabled(instance, session)) {
            prank(instance.account);
            Session[] memory sessions = new Session[](1);
            sessions[0] = session;
            instance.smartSession.enableSessions(sessions);
        }

        // Sign user op
        userOpData.userOp.signature = EncodeLib.encodeUse(permissionId, userOpData.userOp.signature);

        // Execute user op
        userOpData.execUserOps();
    }

    /// @notice Creates multi-chain enable data for a session
    /// @param instance AccountInstance struct containing the account and accountHelper
    /// @param session The session to enable
    /// @param mode The SmartSessionMode to use
    /// @return enableData The enable session data
    function makeMultiChainEnableData(
        AccountInstance memory instance,
        Session memory session,
        SmartSessionMode mode
    )
        internal
        returns (EnableSession memory enableData)
    {
        PermissionId permissionId = instance.getPermissionId(session);
        bytes32 sessionDigest = instance.smartSession.getSessionDigest({
            permissionId: permissionId,
            account: instance.account,
            data: session,
            mode: mode
        });

        ChainDigest[] memory chainDigests = ModuleKitHelpers.encodeHashesAndChainIds(
            Solarray.uint64s(181_818, uint64(block.chainid), 777),
            Solarray.bytes32s(sessionDigest, sessionDigest, sessionDigest)
        );

        enableData = EnableSession({
            chainDigestIndex: 1,
            hashesAndChainIds: chainDigests,
            sessionToEnable: session,
            permissionEnableSig: ""
        });
    }

    /// @dev Encodes hashes and chain ids to a ChainDigest array
    /// @param chainIds The chain ids to encode
    /// @param hashes The hashes to encode
    /// @return ChainDigest[] The encoded ChainDigest array
    function encodeHashesAndChainIds(
        uint64[] memory chainIds,
        bytes32[] memory hashes
    )
        internal
        pure
        returns (ChainDigest[] memory)
    {
        uint256 length = chainIds.length;
        ChainDigest[] memory hashesAndChainIds = new ChainDigest[](length);
        for (uint256 i; i < length; i++) {
            hashesAndChainIds[i] = ChainDigest({ chainId: chainIds[i], sessionDigest: hashes[i] });
        }
        return hashesAndChainIds;
    }
}
