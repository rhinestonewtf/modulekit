// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    AccountInstance,
    UserOpData,
    AccountType,
    DEFAULT,
    SAFE,
    NEXUS,
    KERNEL,
    CUSTOM
} from "./RhinestoneModuleKit.sol";
import { ERC4337Helpers } from "./utils/ERC4337Helpers.sol";
import { HelperBase } from "./helpers/HelperBase.sol";
import { Execution } from "../external/ERC7579.sol";
import {
    getAccountType as getAccountTypeFromStorage,
    writeAccountType,
    writeExpectRevert,
    writeGasIdentifier,
    writeSimulateUserOp,
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

library ModuleKitHelpers {
    /*//////////////////////////////////////////////////////////////////////////
                                      ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidAccountType();

    /*//////////////////////////////////////////////////////////////////////////
                                    LIBRARIES
    //////////////////////////////////////////////////////////////////////////*/

    using ModuleKitHelpers for AccountInstance;
    using ModuleKitHelpers for UserOpData;
    using ModuleKitHelpers for AccountType;

    /*//////////////////////////////////////////////////////////////////////////
                                    EXECUTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function execUserOps(UserOpData memory userOpData) internal {
        // send userOp to entrypoint
        ERC4337Helpers.exec4337(userOpData.userOp, userOpData.entrypoint);
    }

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
        (userOpData.userOp, userOpData.userOpHash) = HelperBase(instance.accountHelper).execUserOp({
            instance: instance,
            callData: erc7579ExecCall,
            txValidator: txValidator
        });
        userOpData.entrypoint = instance.aux.entrypoint;
    }

    function getExecOps(
        AccountInstance memory instance,
        Execution[] memory executions,
        address txValidator
    )
        internal
        returns (UserOpData memory userOpData)
    {
        bytes memory erc7579ExecCall = HelperBase(instance.accountHelper).encode(executions);
        (userOpData.userOp, userOpData.userOpHash) = HelperBase(instance.accountHelper).execUserOp({
            instance: instance,
            callData: erc7579ExecCall,
            txValidator: txValidator
        });
        userOpData.entrypoint = instance.aux.entrypoint;
    }

    function exec(
        AccountInstance memory instance,
        address target,
        uint256 value,
        bytes memory callData
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData =
            instance.getExecOps(target, value, callData, address(instance.defaultValidator));
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        userOpData.entrypoint = instance.aux.entrypoint;
        // send userOp to entrypoint
        userOpData.execUserOps();
    }

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

    /*//////////////////////////////////////////////////////////////////////////
                                MODULE CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function installModule(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        returns (UserOpData memory userOpData)
    {
        userOpData = instance.getInstallModuleOps(
            moduleTypeId, module, data, address(instance.defaultValidator)
        );
        // sign userOp with default signature
        userOpData = userOpData.signDefault();
        userOpData.entrypoint = instance.aux.entrypoint;
        // send userOp to entrypoint
        userOpData.execUserOps();
    }

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
    }

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module
    )
        internal
        view
        returns (bool)
    {
        return HelperBase(instance.accountHelper).isModuleInstalled(instance, moduleTypeId, module);
    }

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        internal
        view
        returns (bool)
    {
        return HelperBase(instance.accountHelper).isModuleInstalled(
            instance, moduleTypeId, module, data
        );
    }

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
            .configModuleUserOp({
            instance: instance,
            moduleType: moduleType,
            module: module,
            initData: initData,
            isInstall: true,
            txValidator: txValidator
        });
        userOpData.entrypoint = instance.aux.entrypoint;
    }

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
            .configModuleUserOp({
            instance: instance,
            moduleType: moduleType,
            module: module,
            initData: initData,
            isInstall: false,
            txValidator: txValidator
        });
        userOpData.entrypoint = instance.aux.entrypoint;
    }

    function getInstalledModules(AccountInstance memory instance)
        internal
        view
        returns (InstalledModule[] memory)
    {
        return getInstalledModulesFromStorage(instance.account);
    }

    function writeInstalledModule(
        AccountInstance memory instance,
        InstalledModule memory module
    )
        internal
    {
        writeInstalledModuleToStorage(module, instance.account);
    }

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
    /*//////////////////////////////////////////////////////////////////////////
                                CONTROL FLOW
    //////////////////////////////////////////////////////////////////////////*/

    function expect4337Revert(AccountInstance memory) internal {
        writeExpectRevert(1);
    }

    /**
     * @dev Logs the gas used by an ERC-4337 transaction
     * @dev needs to be called before an exec4337 call
     * @dev the id needs to be unique across your tests, otherwise the gas calculations will
     * overwrite each other
     *
     * @param id Identifier for the gas calculation, which will be used as the filename
     */
    function log4337Gas(AccountInstance memory, /* instance */ string memory id) internal {
        writeGasIdentifier(id);
    }

    function simulateUserOp(AccountInstance memory, bool value) internal {
        writeSimulateUserOp(value);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ACCOUNT UTILS
    //////////////////////////////////////////////////////////////////////////*/

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

    function setAccountType(AccountInstance memory, AccountType env) internal {
        setAccountType(env);
    }

    function setAccountType(AccountType env) internal {
        writeAccountType(env.toString());
    }

    function setAccountEnv(AccountInstance memory, string memory env) internal {
        setAccountEnv(env);
    }

    function setAccountEnv(string memory env) internal {
        _setAccountEnv(env);
    }

    function setAccountEnv(AccountType env) internal {
        _setAccountEnv(env.toString());
    }

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

    function getAccountType(AccountInstance memory)
        internal
        view
        returns (AccountType accountType)
    {
        return getAccountType();
    }

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

    function getAccountEnv(AccountInstance memory)
        internal
        view
        returns (AccountType env, address, address)
    {
        return getAccountEnv();
    }

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

    /*//////////////////////////////////////////////////////////////////////////
                                SIGNATURE UTILS
    //////////////////////////////////////////////////////////////////////////*/

    function isValidSignature(
        AccountInstance memory instance,
        address validator,
        bytes32 hash,
        bytes memory signature
    )
        internal
        returns (bool)
    {
        return HelperBase(instance.accountHelper).isValidSignature({
            instance: instance,
            validator: validator,
            hash: hash,
            signature: signature
        });
    }

    function formatERC1271Hash(
        AccountInstance memory instance,
        address validator,
        bytes32 hash
    )
        internal
        returns (bytes32)
    {
        return HelperBase(instance.accountHelper).formatERC1271Hash({
            instance: instance,
            validator: validator,
            hash: hash
        });
    }

    function formatERC1271Signature(
        AccountInstance memory instance,
        address validator,
        bytes memory signature
    )
        internal
        returns (bytes memory)
    {
        return HelperBase(instance.accountHelper).formatERC1271Signature({
            instance: instance,
            validator: validator,
            signature: signature
        });
    }

    function signDefault(UserOpData memory userOpData) internal pure returns (UserOpData memory) {
        userOpData.userOp.signature = "DEFAULT SIGNATURE";
        return userOpData;
    }
}
