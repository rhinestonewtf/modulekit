pragma solidity ^0.8.23;

import { ValidatorLib } from "kernel/utils/ValidationTypeLib.sol";
import { ValidationType, ValidationMode, ValidationId } from "kernel/types/Types.sol";
import "kernel/types/Constants.sol";
import { ENTRYPOINT_ADDR } from "../predeploy/EntryPoint.sol";
import { IEntryPoint } from "kernel/interfaces/IEntryPoint.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { MockFallback } from "kernel/mock/MockFallback.sol";
import { Kernel } from "kernel/Kernel.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { IValidator } from "kernel/interfaces/IERC7579Modules.sol";
import { etch } from "./Vm.sol";

contract SetSelector is Kernel {
    constructor(IEntryPoint _entrypoint) Kernel(_entrypoint) { }

    function setSelector(ValidationId vId, bytes4 selector, bool allowed) external {
        _setSelector(vId, selector, allowed);
    }
}

library KernelHelpers {
    function encodeNonce(
        ValidationType vType,
        bool enable,
        address account,
        address validator
    )
        internal
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
    function getDefaultInstallValidatorData(
        address module,
        bytes memory initData
    )
        internal
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
        address module,
        bytes memory initData
    )
        internal
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
        address module,
        bytes memory initData
    )
        internal
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
        address module,
        bytes memory initData
    )
        internal
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
        internal
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
        internal
        pure
        returns (bytes memory data)
    { }

    /**
     * @dev
     * https://github.com/zerodevapp/kernel/blob/a807c8ec354a77ebb7cdb73c5be9dd315cda0df2/src/Kernel.sol#L402-L403
     */
    function getDefaultUninstallFallbackData(
        address module,
        bytes memory deinitData
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(MockFallback.fallbackFunction.selector, deinitData);
    }
}
