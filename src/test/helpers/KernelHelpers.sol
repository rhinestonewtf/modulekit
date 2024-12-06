// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Types
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { ValidationType, ValidationMode, ValidationId } from "../../accounts/kernel/types/Types.sol";
import {
    VALIDATION_TYPE_PERMISSION,
    VALIDATION_TYPE_ROOT,
    VALIDATION_TYPE_VALIDATOR,
    VALIDATION_MODE_DEFAULT,
    VALIDATION_MODE_ENABLE,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_VALIDATOR,
    KERNEL_WRAPPER_TYPE_HASH
} from "../../accounts/kernel/types/Constants.sol";
import { CallType } from "../../accounts/common/lib/ModeLib.sol";
import { Execution } from "../../accounts/erc7579/lib/ExecutionLib.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";

// Libraries
import { ValidatorLib, ValidationConfig } from "../../accounts/kernel/lib/ValidationTypeLib.sol";

// Deployments
import { ENTRYPOINT_ADDR } from "../../deployment/predeploy/EntryPoint.sol";
import { KernelPrecompiles, ISetSelector } from "../../deployment/precompiles/KernelPrecompiles.sol";

// Interfaces
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IERC7579Account } from "../../accounts/kernel/interfaces/IERC7579Account.sol";
import { IKernel } from "../../accounts/kernel/interfaces/IKernel.sol";
import { IValidator, IModule } from "../../accounts/common/interfaces/IERC7579Module.sol";
import { IERC1271, EIP1271_MAGIC_VALUE } from "../../Interfaces.sol";

// Mocks
import { MockFallback } from "../../accounts/kernel/mock/MockFallback.sol";
import { MockHookMultiPlexer } from "../../Mocks.sol";

// Dependencies
import { HelperBase } from "./HelperBase.sol";
import { TrustedForwarder } from "../../Modules.sol";
import { KernelFactory } from "../../accounts/kernel/KernelFactory.sol";

// Utils
import { etch } from "../utils/Vm.sol";

// External Dependencies
import { EIP712 } from "solady/utils/EIP712.sol";

/// @notice Helper functions for the Kernel ERC7579 account implementation
contract KernelHelpers is HelperBase, KernelPrecompiles {
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
        override
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        bool notDeployedYet = instance.account.code.length == 0;
        if (notDeployedYet) {
            initCode = instance.initCode;
        }
        uint256 nonce = getNonce(instance, callData, txValidator);

        address execHook = getExecHook(instance, txValidator);
        if (execHook != address(0) && execHook != address(1)) {
            callData = abi.encodePacked(IKernel.executeUserOp.selector, callData);
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: nonce,
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
                                        NONCE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Gets the nonce for an account instance
    /// @param instance AccountInstance the account instance to get the nonce for
    /// @param callData bytes the calldata to execute
    /// @param txValidator address the address of the validator
    function getNonce(
        AccountInstance memory instance,
        bytes memory callData,
        address txValidator
    )
        public
        virtual
        override
        returns (uint256 nonce)
    {
        ValidationType vType;
        if (txValidator == address(instance.defaultValidator)) {
            vType = VALIDATION_TYPE_ROOT;
        } else {
            enableValidator(instance, callData, txValidator);
            vType = VALIDATION_TYPE_VALIDATOR;
        }
        nonce = encodeNonce(vType, false, instance.account, txValidator);
    }

    /// @notice Encodes the nonce for an account instance in the Kernel format
    /// @param vType ValidationType the validation type
    /// @param enable bool whether to enable the validator
    /// @param account address the address of the account
    /// @param validator address the address of the validator
    /// @return nonce uint256 the encoded nonce
    function encodeNonce(
        ValidationType vType,
        bool enable,
        address account,
        address validator
    )
        public
        view
        returns (uint256 nonce)
    {
        uint192 nonceKey = 0;
        if (vType == VALIDATION_TYPE_ROOT) {
            nonceKey = 0;
        } else if (vType == VALIDATION_TYPE_VALIDATOR) {
            ValidationMode mode = VALIDATION_MODE_DEFAULT;
            if (enable) {
                mode = VALIDATION_MODE_ENABLE;
            }
            nonceKey = ValidatorLib.encodeAsNonceKey(
                ValidationMode.unwrap(mode),
                ValidationType.unwrap(vType),
                bytes20(validator),
                0 // parallel key
            );
        } else {
            revert("Invalid validation type");
        }
        return IEntryPoint(ENTRYPOINT_ADDR).getNonce(account, nonceKey);
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
        override
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        if (instance.account.code.length == 0) {
            initCode = instance.initCode;
        }
        bytes memory callData;
        if (isInstall) {
            initData = getInstallModuleData({
                instance: instance,
                moduleType: moduleType,
                module: module,
                initData: initData
            });
            callData = getInstallModuleCallData({
                instance: instance,
                moduleType: moduleType,
                module: module,
                initData: initData
            });
        } else {
            initData = getUninstallModuleData({
                instance: instance,
                moduleType: moduleType,
                module: module,
                initData: initData
            });
            callData = getUninstallModuleCallData({
                instance: instance,
                moduleType: moduleType,
                module: module,
                initData: initData
            });
        }

        address execHook = getExecHook(instance, txValidator);
        if (execHook != address(0) && execHook != address(1)) {
            callData = abi.encodePacked(IKernel.executeUserOp.selector, callData);
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

    /// @notice Enables a validator for an account instance
    /// @param instance AccountInstance the account instance to enable the validator for
    /// @param callData bytes the calldata to execute
    /// @param txValidator address the address of the validator
    function enableValidator(
        AccountInstance memory instance,
        bytes memory callData,
        address txValidator
    )
        internal
        deployAccountForAction(instance)
    {
        ValidationId vId = ValidatorLib.validatorToIdentifier(IValidator(txValidator));
        bytes4 selector;
        assembly {
            selector := mload(add(callData, 32))
        }
        bool isAllowedSelector = IKernel(payable(instance.account)).isAllowedSelector(vId, selector);
        if (!isAllowedSelector) {
            bytes memory accountCode = instance.account.code;
            address _setSelector = address(deployKernelWithSetSelector(ENTRYPOINT_ADDR));
            etch(instance.account, _setSelector.code);
            ISetSelector(payable(instance.account)).setSelector(vId, selector, true);
            etch(instance.account, accountCode);
        }
    }

    /// @notice Gets the data to install a validator on an account instance
    /// @dev
    /// https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/../../Kernel.sol#L311-L321
    /// @param instance AccountInstance the account instance to install the validator on
    /// implementation)
    /// @param initData the data to pass to the validator
    /// @return data the data to install the validator
    function getInstallValidatorData(
        AccountInstance memory instance,
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            getHookMultiPlexer(instance), abi.encode(initData, hex"00", bytes(hex"00000001"))
        );
    }

    /// @notice Gets the data to install an executor on an account instance
    /// @dev
    /// https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/../../Kernel.sol#L324-L334
    /// @param instance AccountInstance the account instance to install the executor on
    /// @param initData the data to pass to the executor
    /// @return data the data to install the executor
    function getInstallExecutorData(
        AccountInstance memory instance,
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            getHookMultiPlexer(instance), abi.encode(initData, abi.encodePacked(bytes1(0x00), ""))
        );
    }

    /// @notice Gets the data to install a fallback on an account instance
    /// @dev
    /// https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/../../Kernel.sol#L336-L345
    /// @param instance AccountInstance the account instance to install the fallback on
    /// @param initData the data to pass to the fallback
    /// @return data the data to install the fallback
    function getInstallFallbackData(
        AccountInstance memory instance,
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory data)
    {
        (bytes4 selector, CallType callType, bytes memory _initData) =
            abi.decode(initData, (bytes4, CallType, bytes));
        data = abi.encodePacked(
            selector,
            getHookMultiPlexer(instance),
            abi.encode(abi.encodePacked(callType, _initData), abi.encodePacked(bytes1(0x00), ""))
        );
    }

    /// @notice Gets the data to uninstall a fallback on an account instance
    /// @dev
    /// https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/../../Kernel.sol#L402-L403
    /// @param initData the data to pass to the fallback
    /// @return data the data to uninstall the fallback
    function getUninstallFallbackData(
        AccountInstance memory, // instance
        address, // module
        bytes memory initData
    )
        public
        pure
        virtual
        override
        returns (bytes memory data)
    {
        (bytes4 selector,, bytes memory _initData) = abi.decode(initData, (bytes4, CallType, bytes));
        data = abi.encodePacked(selector, _initData);
    }

    /// @notice Gets the data to install a module on an account instance
    /// @param instance AccountInstance the account instance to install the module on
    /// @param moduleType uint256 the type of the module
    /// @param module address the address of the module to install
    /// @param initData bytes the data to pass to the module
    /// @return callData the data to install the module
    function getInstallModuleCallData(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory callData)
    {
        if (moduleType == MODULE_TYPE_HOOK) {
            Execution[] memory executions = new Execution[](3);
            executions[0] = Execution({
                target: getHookMultiPlexer(instance),
                value: 0,
                callData: abi.encodeCall(MockHookMultiPlexer.addHook, (module))
            });
            executions[1] = Execution({
                target: module,
                value: 0,
                callData: abi.encodeCall(IModule.onInstall, (initData))
            });
            executions[2] = Execution({
                target: module,
                value: 0,
                callData: abi.encodeCall(
                    TrustedForwarder.setTrustedForwarder, (getHookMultiPlexer(instance))
                )
            });
            callData = encode({ executions: executions });
        } else {
            callData = abi.encodeCall(IERC7579Account.installModule, (moduleType, module, initData));
        }
    }

    /// @notice Gets the data to uninstall a module on an account instance
    /// @param instance AccountInstance the account instance to uninstall the module from
    /// @param moduleType uint256 the type of the module
    /// @param module address the address of the module to uninstall
    /// @param initData bytes the data to pass to the module
    /// @return callData the data to uninstall the module
    function getUninstallModuleCallData(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory callData)
    {
        if (moduleType == MODULE_TYPE_HOOK) {
            Execution[] memory executions = new Execution[](3);
            executions[0] = Execution({
                target: getHookMultiPlexer(instance),
                value: 0,
                callData: abi.encodeCall(MockHookMultiPlexer.removeHook, (module))
            });
            executions[1] = Execution({
                target: module,
                value: 0,
                callData: abi.encodeCall(IModule.onUninstall, (initData))
            });
            executions[2] = Execution({
                target: module,
                value: 0,
                callData: abi.encodeCall(TrustedForwarder.clearTrustedForwarder, ())
            });
            callData = encode({ executions: executions });
        } else {
            callData =
                abi.encodeCall(IERC7579Account.uninstallModule, (moduleType, module, initData));
        }
    }

    /// @notice Checks if a module is installed on an account instance
    /// @param instance AccountInstance the account instance to check the module on
    /// @param moduleTypeId uint256 the type of the module
    /// @param module address the address of the module to check
    /// @param data bytes the data to pass to the module
    /// @return bool whether the module is installed
    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        public
        virtual
        override
        deployAccountForAction(instance)
        returns (bool)
    {
        if (moduleTypeId == MODULE_TYPE_HOOK) {
            return MockHookMultiPlexer(getHookMultiPlexer(instance)).isHookInstalled(
                instance.account, module
            );
        }

        return IERC7579Account(instance.account).isModuleInstalled(moduleTypeId, module, data);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    SIGNATURE UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks if a signature is valid for an account instance
    /// @param instance AccountInstance the account instance to check the signature on
    /// @param validator address the address of the validator
    /// @param hash bytes32 the hash of the data that is signed
    /// @param signature bytes the signature to check
    /// @return isValid bool whether the signature is valid, return true if isValidSignature return
    /// EIP1271_MAGIC_VALUE
    function isValidSignature(
        AccountInstance memory instance,
        address validator,
        bytes32 hash,
        bytes memory signature
    )
        public
        virtual
        override
        deployAccountForAction(instance)
        returns (bool isValid)
    {
        isValid = IERC1271(instance.account).isValidSignature(
            hash,
            abi.encodePacked(ValidatorLib.validatorToIdentifier(IValidator(validator)), signature)
        ) == EIP1271_MAGIC_VALUE;
    }

    /// @notice Formats a ERC1271 hash for an account instance
    /// @param instance AccountInstance the account instance to format the signature for
    /// @param hash bytes32 the hash to format
    /// @return bytes the formatted signature hash
    function formatERC1271Hash(
        AccountInstance memory instance,
        address, // validator
        bytes32 hash
    )
        public
        virtual
        override
        deployAccountForAction(instance)
        returns (bytes32)
    {
        return IKernel(payable(instance.account))._toWrappedHash(hash);
    }

    /// @notice Formats an ERC1271 signature for an account instance
    /// @param validator address the address of the validator
    /// @param signature bytes the signature to format
    /// @return bytes the formatted signature
    function formatERC1271Signature(
        AccountInstance memory, // instance
        address validator,
        bytes memory signature
    )
        public
        virtual
        override
        returns (bytes memory)
    {
        return
            abi.encodePacked(ValidatorLib.validatorToIdentifier(IValidator(validator)), signature);
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK MULTIPLEXER
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the hook multiplexer for an account instance
    /// @param instance AccountInstance the account instance to get the hook multiplexer for
    /// @return address the address of the hook multiplexer
    function getHookMultiPlexer(AccountInstance memory instance) public view returns (address) {
        return address(KernelFactory(instance.accountFactory).hookMultiPlexer());
    }

    /// @notice Sets the hook multiplexer for an account instance
    /// @param instance AccountInstance the account instance to set the hook multiplexer for
    /// @param hookMultiPlexer address the address of the hook multiplexer
    function setHookMultiPlexer(
        AccountInstance memory instance,
        address hookMultiPlexer
    )
        public
        virtual
        deployAccountForAction(instance)
    {
        KernelFactory(instance.accountFactory).setHookMultiPlexer(hookMultiPlexer);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Gets the exec hook for an account instance
    /// @param instance AccountInstance the account instance to get the exec hook for
    /// @param txValidator address the address of the validator
    /// @return address the address of the exec hook
    function getExecHook(
        AccountInstance memory instance,
        address txValidator
    )
        internal
        deployAccountForAction(instance)
        returns (address)
    {
        ValidationId vId = ValidatorLib.validatorToIdentifier(IValidator(txValidator));
        ValidationConfig memory validationConfig =
            IKernel(payable(instance.account)).validationConfig(vId);
        return address(validationConfig.hook);
    }
}
