// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Interfaces
import { IERC7579Account } from "../../accounts/common/interfaces/IERC7579Account.sol";
import {
    IModule as IERC7579Module,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_FALLBACK
} from "../../accounts/common/interfaces/IERC7579Module.sol";
import { IERC1271, EIP1271_MAGIC_VALUE } from "../../Interfaces.sol";

// Libraries
import {
    ModeLib,
    ModeCode,
    CALLTYPE_SINGLE,
    CALLTYPE_BATCH,
    MODE_DEFAULT,
    EXECTYPE_DEFAULT,
    CALLTYPE_BATCH,
    ModePayload
} from "../../accounts/common/lib/ModeLib.sol";

// Types
import { PackedUserOperation } from "../../external/ERC4337.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { Execution } from "../../accounts/erc7579/lib/ExecutionLib.sol";

// Utils
import "../utils/Vm.sol";

/// @dev Base helper that includes common functions for different ERC7579 Account implementations
abstract contract HelperBase {
    /*//////////////////////////////////////////////////////////////////////////
                                    EXECUTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Gets userOp and userOpHash for an executing calldata on an account instance
    /// @param instance AccountInstance the account instance to execute the userop for
    /// @param callData bytes the calldata to execute
    /// @param txValidator address the address of the validator
    /// @return userOp PackedUserOperation the packed user operation
    /// @return userOpHash bytes32 the hash of the user operation
    function execUserOp(
        AccountInstance memory instance,
        bytes memory callData,
        address txValidator
    )
        public
        virtual
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        bool notDeployedYet = instance.account.code.length == 0;
        if (notDeployedYet) {
            initCode = instance.initCode;
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(instance, callData, txValidator),
            initCode: initCode,
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });

        userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODULE CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Configures a userop for an account instance to install or uninstall a module
    /// @param instance AccountInstance the account instance to configure the userop for
    /// @param moduleType uint256 the type of the module
    /// @param module address the address of the module
    /// @param initData bytes the data to pass to the module
    /// @param isInstall bool whether to install or uninstall the module
    /// @param txValidator address the address of the validator
    /// @return userOp PackedUserOperation the packed user operation
    /// @return userOpHash bytes32 the hash of the user operation
    function configModuleUserOp(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData,
        bool isInstall,
        address txValidator
    )
        public
        virtual
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        if (instance.account.code.length == 0) {
            initCode = instance.initCode;
        }
        bytes memory callData;
        if (isInstall) {
            initData = getInstallModuleData(instance, moduleType, module, initData);
            callData = getInstallModuleCallData(instance, moduleType, module, initData);
        } else {
            initData = getUninstallModuleData(instance, moduleType, module, initData);
            callData = getUninstallModuleCallData(instance, moduleType, module, initData);
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(instance, callData, txValidator),
            initCode: initCode,
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });

        userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
    }

    /// @notice get callData to install a module on an ERC7579 Account
    /// @param moduleType uint256 the type of the module
    /// @param module address the address of the module to install
    /// @param initData bytes the data to pass to the module
    /// @return callData bytes the callData to install the module
    function getInstallModuleCallData(
        AccountInstance memory, // instance
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(IERC7579Account.installModule, (moduleType, module, initData));
    }

    /// @notice get callData to uninstall a module on an ERC7579 Account
    /// @param moduleType uint256 the type of the module
    /// @param module address the address of the module to uninstall
    /// @param initData bytes the data to pass to the module
    /// @return callData bytes the callData to uninstall the module
    function getUninstallModuleCallData(
        AccountInstance memory, // instance
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(IERC7579Account.uninstallModule, (moduleType, module, initData));
    }

    /// @notice get callData to install a validator on an ERC7579 Account
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the callData to install the validator
    function getInstallValidatorData(
        AccountInstance memory, // instance
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /// @notice get callData to uninstall a validator on an ERC7579 Account
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the callData to uninstall the validator
    function getUninstallValidatorData(
        AccountInstance memory, // instance
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /// @notice get callData to install executor on ERC7579 Account
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the callData to install the executor
    function getInstallExecutorData(
        AccountInstance memory, //  instance
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /// @notice get callData to uninstall executor on ERC7579 Account
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the callData to uninstall the executor
    function getUninstallExecutorData(
        AccountInstance memory, // instance
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /// @notice get callData to install hook on ERC7579 Account
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the callData to install the hook
    function getInstallHookData(
        AccountInstance memory, // instance
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /// @notice get callData to uninstall hook on ERC7579 Account
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the callData to uninstall the hook
    function getUninstallHookData(
        AccountInstance memory, // instance
        address, // module
        bytes memory initData
    )
        public
        pure
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /// @notice get callData to install fallback on ERC7579 Account
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the callData to install the fallback
    function getInstallFallbackData(
        AccountInstance memory, // instance
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /// @notice get callData to uninstall fallback on ERC7579 Account
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the callData to uninstall the fallback
    function getUninstallFallbackData(
        AccountInstance memory, // instance
        address, // module
        bytes memory initData
    )
        public
        pure
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODULE UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks if a module is installed on an ERC7579 Account
    /// @param instance AccountInstance the account instance to check the module on
    /// @param moduleTypeId uint256 the type of the module
    /// @param module address the address of the module to check
    /// @return bool whether the module is installed
    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module
    )
        public
        virtual
        deployAccountForAction(instance)
        returns (bool)
    {
        return isModuleInstalled(instance, moduleTypeId, module, "");
    }

    /// @notice Checks if a module is installed on an ERC7579 Account
    /// @param instance AccountInstance the account instance to check the module on
    /// @param moduleTypeId uint256 the type of the module
    /// @param module address the address of the module to check
    /// @param additionalContext bytes additional context to pass to the module
    /// @return bool whether the module is installed
    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory additionalContext
    )
        public
        virtual
        deployAccountForAction(instance)
        returns (bool)
    {
        return IERC7579Account(instance.account).isModuleInstalled(
            moduleTypeId, module, additionalContext
        );
    }

    /// @notice Gets the data to install a module on an ERC7579 Account, based on the module type
    /// @param instance AccountInstance the account instance to install the module on
    /// @param moduleType uint256 the type of the module
    /// @param module address the address of the module to install
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the data to install the module
    function getInstallModuleData(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            return getInstallValidatorData(instance, module, initData);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            return getInstallExecutorData(instance, module, initData);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            return getInstallHookData(instance, module, initData);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            return getInstallFallbackData(instance, module, initData);
        } else {
            revert("Invalid module type");
        }
    }

    /// @notice Gets the data to uninstall a module on an ERC7579 Account, based on the module type
    /// @param instance AccountInstance the account instance to uninstall the module from
    /// @param moduleType uint256 the type of the module
    /// @param module address the address of the module to uninstall
    /// @param initData bytes the data to pass to the module
    /// @return data bytes the data to uninstall the module
    function getUninstallModuleData(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            return getUninstallValidatorData(instance, module, initData);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            return getUninstallExecutorData(instance, module, initData);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            return getUninstallHookData(instance, module, initData);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            return getUninstallFallbackData(instance, module, initData);
        } else {
            revert("Invalid module type");
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    SIGNATURE UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks if a signature is valid for an account instance
    /// @param instance AccountInstance the account instance to check the signature on
    /// @param hash bytes32 the hash to check the signature against
    /// @param signature bytes the signature to check
    /// @return isValid bool whether the signature is valid, returns true if isValidSignature
    /// returns EIP1271_MAGIC_VALUE
    function isValidSignature(
        AccountInstance memory instance,
        address, // validator
        bytes32 hash,
        bytes memory signature
    )
        public
        virtual
        deployAccountForAction(instance)
        returns (bool isValid)
    {
        isValid =
            IERC1271(instance.account).isValidSignature(hash, signature) == EIP1271_MAGIC_VALUE;
    }

    /// @notice Formats a hash for an ERC1271 signature
    /// @param hash bytes32 the hash to format
    /// @return bytes32 the formatted hash
    function formatERC1271Hash(
        AccountInstance memory, // instance
        address, //validator
        bytes32 hash
    )
        public
        virtual
        returns (bytes32)
    {
        return hash;
    }

    /// @notice Formats a signature for an ERC1271 signature
    /// @param signature bytes the signature to format
    /// @return bytes the formatted signature
    function formatERC1271Signature(
        AccountInstance memory, // instance
        address, // validator
        bytes memory signature
    )
        public
        virtual
        returns (bytes memory)
    {
        return signature;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    ACCOUNT UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deploys an account instance, if it has not been deployed yet
    ///         reverts if no initCode is provided
    /// @param instance AccountInstance the account instance to deploy
    function deployAccount(AccountInstance memory instance) public virtual {
        if (instance.account.code.length == 0) {
            if (instance.initCode.length == 0) {
                revert("deployAccount: no initCode provided");
            } else {
                bytes memory initCode = instance.initCode;
                assembly {
                    let factory := mload(add(initCode, 20))
                    let success := call(gas(), factory, 0, add(initCode, 52), mload(initCode), 0, 0)
                    if iszero(success) { revert(0, 0) }
                }
            }
        }
    }

    /// @notice Deploys an account instance, if it has not been deployed yet, and reverts to the
    ///         snapshot after the action
    modifier deployAccountForAction(AccountInstance memory instance) {
        bool isAccountDeployed = instance.account.code.length != 0;
        uint256 snapShotId;
        if (!isAccountDeployed) {
            snapShotId = snapshot();
            deployAccount(instance);
        }

        _;

        if (!isAccountDeployed) {
            revertTo(snapShotId);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Encode a single ERC7579 Execution Transaction
    /// @param target address the target
    /// @param value uint256 the value
    /// @param callData bytes the callData of the call
    /// @return erc7579Tx bytes the encoded ERC7579 transaction
    function encode(
        address target,
        uint256 value,
        bytes memory callData
    )
        public
        pure
        virtual
        returns (bytes memory erc7579Tx)
    {
        ModeCode mode = ModeLib.encode({
            callType: CALLTYPE_SINGLE,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });
        bytes memory data = abi.encodePacked(target, value, callData);
        return abi.encodeCall(IERC7579Account.execute, (mode, data));
    }

    /// @notice Encode a batch of ERC7579 Execution Transactions
    /// @param executions Execution[] the array of executions
    /// @return erc7579Tx bytes the encoded ERC7579 transaction
    function encode(Execution[] memory executions)
        public
        pure
        virtual
        returns (bytes memory erc7579Tx)
    {
        ModeCode mode = ModeLib.encode({
            callType: CALLTYPE_BATCH,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });
        return abi.encodeCall(IERC7579Account.execute, (mode, abi.encode(executions)));
    }

    /// @notice Convert arrays of targets, values, and callDatas to an array of Executions
    /// @param targets address[] the array of targets
    /// @param values uint256[] the array of values
    /// @param callDatas bytes[] the array of callDatas
    /// @return executions Execution[] the array of encoded executions
    function toExecutions(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory callDatas
    )
        public
        pure
        virtual
        returns (Execution[] memory executions)
    {
        executions = new Execution[](targets.length);
        if (targets.length != values.length && values.length != callDatas.length) {
            revert("Length Mismatch");
        }

        for (uint256 i; i < targets.length; i++) {
            executions[i] =
                Execution({ target: targets[i], value: values[i], callData: callDatas[i] });
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     NONCE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Get the nonce for an account instance
    /// @param instance AccountInstance the account instance to get the nonce for
    /// @param txValidator address the address of the validator
    /// @return nonce uint256 the nonce
    function getNonce(
        AccountInstance memory instance,
        bytes memory,
        address txValidator
    )
        public
        virtual
        returns (uint256 nonce)
    {
        uint192 key = uint192(bytes24(bytes20(address(txValidator))));
        nonce = instance.aux.entrypoint.getNonce(address(instance.account), key);
    }
}
