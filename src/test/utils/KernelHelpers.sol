pragma solidity ^0.8.23;

import { ValidatorLib } from "kernel/utils/ValidationTypeLib.sol";
import { ValidationType, ValidationMode } from "kernel/types/Types.sol";
import "kernel/types/Constants.sol";
import { ENTRYPOINT_ADDR } from "../predeploy/EntryPoint.sol";
import { IEntryPoint } from "kernel/interfaces/IEntryPoint.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { MockFallback } from "kernel/mock/MockFallback.sol";

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

    function getDefaultInstallExecutorData(address module)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodeWithSelector(
            IERC7579Account.installModule.selector,
            MODULE_TYPE_EXECUTOR,
            address(module),
            abi.encodePacked(
                address(0), abi.encode(abi.encodePacked("executorData"), abi.encodePacked(""))
            )
        );
    }

    function getDefaultInstallValidatorData(address module)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodeWithSelector(
            IERC7579Account.installModule.selector,
            MODULE_TYPE_VALIDATOR,
            address(module),
            abi.encodePacked(
                address(0), abi.encode(abi.encodePacked("validatorData"), abi.encodePacked(""))
            )
        );
    }

    function getDefaultInstallFallbackData(address module)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodeWithSelector(
            IERC7579Account.installModule.selector,
            MODULE_TYPE_FALLBACK,
            address(module),
            abi.encodePacked(
                MockFallback.fallbackFunction.selector,
                address(0),
                abi.encode(abi.encodePacked(hex"00", "fallbackData"), abi.encodePacked(""))
            )
        );
    }

    function getDefaultInstallHookData(address module) internal pure returns (bytes memory data) {
        //TODO fix hook data computation
        data = abi.encodeWithSelector(
            IERC7579Account.installModule.selector,
            MODULE_TYPE_HOOK,
            address(module),
            abi.encodePacked(
                address(1), abi.encode(hex"ff", abi.encodePacked(bytes1(0xff), "hookData"))
            )
        );
    }

    function getDefaultUninstallExecutorData(address module)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodeWithSelector(
            IERC7579Account.uninstallModule.selector, MODULE_TYPE_EXECUTOR, module, hex""
        );
    }

    function getDefaultUninstallValidatorData(address module)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodeWithSelector(
            IERC7579Account.uninstallModule.selector, MODULE_TYPE_VALIDATOR, module, hex""
        );
    }

    function getDefaultUninstallFallbackData(address module)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodeWithSelector(
            IERC7579Account.uninstallModule.selector,
            MODULE_TYPE_FALLBACK,
            module,
            abi.encodePacked(MockFallback.fallbackFunction.selector)
        );
    }
}
