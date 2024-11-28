// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { ValidatorLib, ValidationConfig } from "../../accounts/kernel/lib/ValidationTypeLib.sol";
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
import { ENTRYPOINT_ADDR } from "../predeploy/EntryPoint.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IERC7579Account } from "../../accounts/kernel/interfaces/IERC7579Account.sol";
import { MockFallback } from "../../accounts/kernel/mock/MockFallback.sol";
import { HelperBase } from "./HelperBase.sol";
import { IKernel } from "../../accounts/kernel/interfaces/IKernel.sol";
import { etch } from "../utils/Vm.sol";
import { IValidator, IModule } from "../../accounts/common/interfaces/IERC7579Module.sol";
import { IERC1271, EIP1271_MAGIC_VALUE } from "../../Interfaces.sol";
import { CallType } from "../../accounts/common/lib/ModeLib.sol";
import { Execution } from "../../accounts/erc7579/lib/ExecutionLib.sol";
import { MockHookMultiPlexer } from "../../Mocks.sol";
import { TrustedForwarder } from "../../Modules.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";
import { KernelFactory } from "../../accounts/kernel/KernelFactory.sol";
import { EIP712 } from "solady/utils/EIP712.sol";
import { KernelPrecompiles, ISetSelector } from "../../test/precompiles/KernelPrecompiles.sol";

contract KernelHelpers is HelperBase, KernelPrecompiles {
    /*//////////////////////////////////////////////////////////////////////////
                                    EXECUTIONS
    //////////////////////////////////////////////////////////////////////////*/

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

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/../../Kernel.sol#L311-L321
     */
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

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/../../Kernel.sol#L324-L334
     */
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

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/../../Kernel.sol#L336-L345
     */
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

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/../../Kernel.sol#L402-L403
     */
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

    function getHookMultiPlexer(AccountInstance memory instance) public view returns (address) {
        return address(KernelFactory(instance.accountFactory).hookMultiPlexer());
    }

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
