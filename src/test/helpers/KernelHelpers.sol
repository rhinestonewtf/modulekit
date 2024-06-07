// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { ValidatorLib } from "kernel/utils/ValidationTypeLib.sol";
import { ValidationType, ValidationMode, ValidationId } from "kernel/types/Types.sol";
import {
    VALIDATION_TYPE_PERMISSION,
    VALIDATION_TYPE_ROOT,
    VALIDATION_TYPE_VALIDATOR,
    VALIDATION_MODE_DEFAULT,
    VALIDATION_MODE_ENABLE,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_HOOK,
    MODULE_TYPE_VALIDATOR
} from "kernel/types/Constants.sol";
import { ENTRYPOINT_ADDR } from "../predeploy/EntryPoint.sol";
import { IEntryPoint } from "kernel/interfaces/IEntryPoint.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { MockFallback } from "kernel/mock/MockFallback.sol";
import { HelperBase } from "./HelperBase.sol";
import { Kernel } from "kernel/Kernel.sol";
import { etch } from "../utils/Vm.sol";
import { IValidator } from "kernel/interfaces/IERC7579Modules.sol";
import { IERC1271, EIP1271_MAGIC_VALUE } from "src/Interfaces.sol";
import { CallType } from "src/external/ERC7579.sol";
import { MockHookMultiPlexer } from "src/Mocks.sol";

contract SetSelector is Kernel {
    constructor(IEntryPoint _entrypoint) Kernel(_entrypoint) { }

    function setSelector(ValidationId vId, bytes4 selector, bool allowed) external {
        _setSelector(vId, selector, allowed);
    }
}

contract KernelHelpers is HelperBase {
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

    function enableValidator(
        AccountInstance memory instance,
        bytes memory callData,
        address txValidator
    )
        internal
    {
        ValidationId vId = ValidatorLib.validatorToIdentifier(IValidator(txValidator));
        bytes4 selector;
        assembly {
            selector := mload(add(callData, 32))
        }
        bool isAllowedSelector = Kernel(payable(instance.account)).isAllowedSelector(vId, selector);
        if (!isAllowedSelector) {
            bytes memory accountCode = instance.account.code;
            address _setSelector = address(new SetSelector(IEntryPoint(ENTRYPOINT_ADDR)));
            etch(instance.account, _setSelector.code);
            SetSelector(payable(instance.account)).setSelector(vId, selector, true);
            etch(instance.account, accountCode);
        }
    }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L311-L321
     */
    function getInstallValidatorData(
        AccountInstance memory instance,
        address module,
        bytes memory initData
    )
        public
        pure
        virtual
        override
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            address(instance.aux.hookMultiPlexer),
            abi.encode(initData, abi.encodePacked(bytes1(0x00), ""))
        );
    }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L324-L334
     */
    function getInstallExecutorData(
        AccountInstance memory instance,
        address module,
        bytes memory initData
    )
        public
        pure
        virtual
        override
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            address(instance.aux.hookMultiPlexer),
            abi.encode(initData, abi.encodePacked(bytes1(0x00), ""))
        );
    }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L336-L345
     */
    function getInstallFallbackData(
        AccountInstance memory instance,
        address module,
        bytes memory initData
    )
        public
        pure
        virtual
        override
        returns (bytes memory data)
    {
        (bytes4 selector, CallType callType, bytes memory _initData) =
            abi.decode(initData, (bytes4, CallType, bytes));
        data = abi.encodePacked(
            selector,
            address(instance.aux.hookMultiPlexer),
            abi.encode(abi.encodePacked(callType, _initData), abi.encodePacked(bytes1(0x00), ""))
        );
    }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L402-L403
     */
    function getUninstallFallbackData(
        AccountInstance memory instance,
        address module,
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
            callData = encode({
                target: address(instance.aux.hookMultiPlexer),
                value: 0,
                callData: abi.encodeCall(MockHookMultiPlexer.addHook, (module))
            });
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
            callData = encode({
                target: address(instance.aux.hookMultiPlexer),
                value: 0,
                callData: abi.encodeCall(MockHookMultiPlexer.removeHook, (module))
            });
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
        view
        virtual
        override
        returns (bool)
    {
        if (moduleTypeId == MODULE_TYPE_HOOK) {
            return instance.aux.hookMultiPlexer.isHookInstalled(instance.account, module);
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
}
