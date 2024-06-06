pragma solidity ^0.8.23;

import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { ValidatorLib } from "kernel/utils/ValidationTypeLib.sol";
import { ValidationType, ValidationMode } from "kernel/types/Types.sol";
import "kernel/types/Constants.sol";
import { ENTRYPOINT_ADDR } from "../predeploy/EntryPoint.sol";
import { IEntryPoint } from "kernel/interfaces/IEntryPoint.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { MockFallback } from "kernel/mock/MockFallback.sol";
import { HelperBase } from "./HelperBase.sol";

contract KernelHelpers is HelperBase {
    function getNonce(
        address account,
        IEntryPoint,
        address validator,
        address defaultValidator
    )
        public
        view
        virtual
        returns (uint256 nonce)
    {
        ValidationType vType;
        if (validator == defaultValidator) {
            vType = VALIDATION_TYPE_ROOT;
        } else {
            vType = VALIDATION_TYPE_VALIDATOR;
        }
        nonce = encodeNonce(vType, false, account, defaultValidator);
    }

    /**
     * get callData to uninstall executor on ERC7579 Account
     */
    function uninstallExecutor(
        address,
        address executor,
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.uninstallModule, (MODULE_TYPE_EXECUTOR, executor, initData)
        );
    }

    function uninstallValidator(
        address,
        address validator,
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.uninstallModule, (MODULE_TYPE_VALIDATOR, validator, initData)
        );
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

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L311-L321
     */
    function getDefaultInstallValidatorData(
        address,
        bytes memory initData
    )
        public
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(address(0), abi.encode(initData, abi.encodePacked("")));
    }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L324-L334
     */
    function getDefaultInstallExecutorData(
        address,
        bytes memory initData
    )
        public
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(address(0), abi.encode(initData, abi.encodePacked("")));
    }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L336-L345
     */
    function getDefaultInstallFallbackData(
        address,
        bytes memory initData
    )
        public
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            MockFallback.fallbackFunction.selector,
            address(0),
            abi.encode(initData, abi.encodePacked(""))
        );
    }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L311-L321
     */
    function getDefaultInstallHookData(
        address,
        bytes memory initData
    )
        public
        pure
        returns (bytes memory data)
    {
        data = initData;
    }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L397-L398
     */
    function getDefaultUninstallValidatorData(
        address module,
        bytes memory deinitData
    )
        public
        pure
        returns (bytes memory data)
    { }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L400
     */
    function getDefaultUninstallExecutorData(
        address module,
        bytes memory deinitData
    )
        public
        pure
        returns (bytes memory data)
    { }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L402-L403
     */
    function getDefaultUninstallFallbackData(
        address,
        bytes memory deinitData
    )
        public
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(MockFallback.fallbackFunction.selector, deinitData);
    }

    function getInstallModuleData(
        AccountInstance memory,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        public
        view
        virtual
        override
        returns (bytes memory)
    {
        if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
            data = KernelHelpers.getDefaultInstallExecutorData(module, data);
        } else if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
            data = KernelHelpers.getDefaultInstallValidatorData(module, data);
        } else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
            data = KernelHelpers.getDefaultInstallFallbackData(module, data);
        } else {
            //TODO fix hook encoding impl in kernel helpers lib
            data = KernelHelpers.getDefaultInstallHookData(module, data);
        }

        return data;
    }

    function getUninstallModuleData(
        AccountInstance memory,
        uint256 moduleTypeId,
        address module,
        bytes memory data
    )
        public
        view
        virtual
        override
        returns (bytes memory)
    {
        if (moduleTypeId == MODULE_TYPE_EXECUTOR) {
            data = KernelHelpers.getDefaultUninstallExecutorData(module, data);
        } else if (moduleTypeId == MODULE_TYPE_VALIDATOR) {
            data = KernelHelpers.getDefaultUninstallValidatorData(module, data);
        } else if (moduleTypeId == MODULE_TYPE_FALLBACK) {
            data = KernelHelpers.getDefaultUninstallFallbackData(module, data);
        } else {
            //TODO handle for hook
        }
        return data;
    }

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module
    )
        public
        view
        virtual
        override
        returns (bool)
    {
        if (moduleTypeId == MODULE_TYPE_HOOK) {
            return true;
        }
        bytes memory data;

        return isModuleInstalled(instance, moduleTypeId, module, data);
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
            return true;
        }

        return IERC7579Account(instance.account).isModuleInstalled(moduleTypeId, module, data);
    }
}
