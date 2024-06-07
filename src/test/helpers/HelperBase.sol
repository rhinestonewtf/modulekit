// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution, IERC7579Account } from "../../external/ERC7579.sol";
import "erc7579/lib/ModeLib.sol";
import "erc7579/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import "../utils/Vm.sol";

abstract contract HelperBase {
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
            callData = installModule({
                account: instance.account,
                moduleType: moduleType,
                module: module,
                initData: initData
            });
        } else {
            callData = uninstallModule({
                account: instance.account,
                moduleType: moduleType,
                module: module,
                initData: initData
            });
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

    /**
     * Router function to install a module on an ERC7579 account
     */
    function installModule(
        address account,
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory callData)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            initData = getInstallValidatorData(account, module, initData);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            initData = getInstallExecutorData(account, module, initData);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            initData = getInstallHookData(account, module, initData);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            initData = getInstallFallbackData(account, module, initData);
        } else {
            revert("Invalid module type");
        }
        callData = abi.encodeCall(IERC7579Account.installModule, (moduleType, module, initData));
    }

    /**
     * Router function to uninstall a module on an ERC7579 account
     */
    function uninstallModule(
        address account,
        uint256 moduleType,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory callData)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            initData = getUninstallValidatorData(account, module, initData);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            initData = getUninstallExecutorData(account, module, initData);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            initData = getUninstallHookData(account, module, initData);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            initData = getUninstallFallbackData(account, module, initData);
        } else {
            revert("Invalid module type");
        }
        callData = abi.encodeCall(IERC7579Account.uninstallModule, (moduleType, module, initData));
    }

    /**
     * get callData to install validator on ERC7579 Account
     */
    function getInstallValidatorData(
        address, /* account */
        address validator,
        bytes memory initData
    )
        public
        pure
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /**
     * get callData to uninstall validator on ERC7579 Account
     */
    function getUninstallValidatorData(
        address account,
        address validator,
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /**
     * get callData to install executor on ERC7579 Account
     */
    function getInstallExecutorData(
        address, /* account */
        address executor,
        bytes memory initData
    )
        public
        pure
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /**
     * get callData to uninstall executor on ERC7579 Account
     */
    function getUninstallExecutorData(
        address account,
        address executor,
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /**
     * get callData to install hook on ERC7579 Account
     */
    function getInstallHookData(
        address, /* account */
        address hook,
        bytes memory initData
    )
        public
        view
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /**
     * get callData to uninstall hook on ERC7579 Account
     */
    function getUninstallHookData(
        address, /* account */
        address hook,
        bytes memory initData
    )
        public
        pure
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /**
     * get callData to install fallback on ERC7579 Account
     */
    function getInstallFallbackData(
        address, /* account */
        address fallbackHandler,
        bytes memory initData
    )
        public
        pure
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    /**
     * get callData to uninstall fallback on ERC7579 Account
     */
    function getUninstallFallbackData(
        address, /* account */
        address fallbackHandler,
        bytes memory initData
    )
        public
        pure
        virtual
        returns (bytes memory data)
    {
        data = initData;
    }

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module
    )
        public
        view
        virtual
        returns (bool)
    {
        return isModuleInstalled(instance, moduleTypeId, module, "");
    }

    function isModuleInstalled(
        AccountInstance memory instance,
        uint256 moduleTypeId,
        address module,
        bytes memory additionalContext
    )
        public
        view
        virtual
        returns (bool)
    {
        return IERC7579Account(instance.account).isModuleInstalled(
            moduleTypeId, module, additionalContext
        );
    }

    function getInstallModuleData(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory data
    )
        public
        view
        virtual
        returns (bytes memory)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            return getInstallValidatorData(instance.account, module, data);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            return getInstallExecutorData(instance.account, module, data);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            return getInstallHookData(instance.account, module, data);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            return getInstallFallbackData(instance.account, module, data);
        } else {
            revert("Invalid module type");
        }
    }

    function getUninstallModuleData(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory data
    )
        public
        view
        virtual
        returns (bytes memory)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            return getUninstallValidatorData(instance.account, module, data);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            return getUninstallExecutorData(instance.account, module, data);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            return getUninstallHookData(instance.account, module, data);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            return getUninstallFallbackData(instance.account, module, data);
        } else {
            revert("Invalid module type");
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Encode a single ERC7579 Execution Transaction
     * @param target target of the call
     * @param value the value of the call
     * @param callData the calldata of the call
     */
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

    /**
     * Encode a batched ERC7579 Execution Transaction
     * @param executions ERC7579 batched executions
     */
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

    /**
     * convert arrays to batched IERC7579Account
     */
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
