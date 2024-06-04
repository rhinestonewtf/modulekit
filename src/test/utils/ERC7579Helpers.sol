// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    Execution,
    IERC7579Account,
    ERC7579BootstrapConfig,
    IERC7579Validator
} from "../../external/ERC7579.sol";
import "erc7579/lib/ModeLib.sol";
import "erc7579/interfaces/IERC7579Module.sol";
import { PackedUserOperation, IEntryPoint } from "../../external/ERC4337.sol";
import { AccountInstance, AccountType, getAccountType } from "../RhinestoneModuleKit.sol";
import "./Vm.sol";
import { ValidationType } from "kernel/types/Types.sol";
import { VALIDATION_TYPE_ROOT, VALIDATION_TYPE_VALIDATOR } from "kernel/types/Constants.sol";
import { KernelHelpers } from "./KernelHelpers.sol";
import { HookType } from "safe7579/DataTypes.sol";
import { SafeHelpers } from "./SafeHelpers.sol";

interface IAccountModulesPaginated {
    function getValidatorPaginated(
        address,
        uint256
    )
        external
        view
        returns (address[] memory, address);

    function getExecutorsPaginated(
        address,
        uint256
    )
        external
        view
        returns (address[] memory, address);
}

library ERC7579Helpers {
    /**
     * @dev install/uninstall a module on an ERC7579 account
     *
     * @param account IERC7579Account address
     * @param module IERC7579Module address
     * @param initData bytes encoded initialization data.
     *               initData will be passed to fn
     * @param fn function parameter that will yield the initData
     *
     * @return erc7579Tx bytes encoded single ERC7579Execution
     *
     *
     *
     *   can be used like so:
     *   bytes memory installCallData = configModule(
     *                        validator,
     *                        initData,
     *                        ERC7579Helpers.installValidator);
     *
     */
    function configModule(
        address account,
        uint256 moduleType,
        address module,
        bytes memory initData,
        function(address, uint256, address, bytes memory)
            internal
            returns (bytes memory) fn
    )
        internal
        returns (bytes memory erc7579Tx)
    {
        erc7579Tx = fn(account, moduleType, module, initData);
    }

    function configModuleUserOp(
        AccountInstance memory instance,
        uint256 moduleType,
        address module,
        bytes memory initData,
        function(address, uint256, address, bytes memory)
            internal
            returns (bytes memory) fn,
        address txValidator
    )
        internal
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        if (instance.account.code.length == 0) {
            initCode = instance.initCode;
        }

        bytes memory callData = configModule(instance.account, moduleType, module, initData, fn);

        if (getAccountType() == AccountType.SAFE) {
            if (initCode.length != 0) {
                (initCode, callData) =
                    SafeHelpers.getInitCallData(instance.salt, txValidator, initCode, callData);
            }
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(
                instance.account,
                instance.aux.entrypoint,
                txValidator,
                address(instance.defaultValidator)
            ),
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

    function execUserOp(
        AccountInstance memory instance,
        bytes memory callData,
        address txValidator
    )
        internal
        view
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        bool notDeployedYet = instance.account.code.length == 0;
        if (notDeployedYet) {
            initCode = instance.initCode;
        }

        AccountType env = getAccountType();
        if (env == AccountType.SAFE) {
            if (initCode.length != 0) {
                (initCode, callData) =
                    SafeHelpers.getInitCallData(instance.salt, txValidator, initCode, callData);
            }
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(
                instance.account,
                instance.aux.entrypoint,
                txValidator,
                address(instance.defaultValidator)
            ),
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
        internal
        view
        returns (bytes memory callData)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            return installValidator(account, module, initData);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            return installExecutor(account, module, initData);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            return installHook(account, module, initData);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            return installFallback(account, module, initData);
        } else {
            revert("Invalid module type");
        }
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
        internal
        view
        returns (bytes memory callData)
    {
        if (moduleType == MODULE_TYPE_VALIDATOR) {
            return uninstallValidator(account, module, initData);
        } else if (moduleType == MODULE_TYPE_EXECUTOR) {
            return uninstallExecutor(account, module, initData);
        } else if (moduleType == MODULE_TYPE_HOOK) {
            return uninstallHook(account, module, initData);
        } else if (moduleType == MODULE_TYPE_FALLBACK) {
            return uninstallFallback(account, module, initData);
        } else {
            revert("Invalid module type");
        }
    }

    /**
     * get callData to install validator on ERC7579 Account
     */
    function installValidator(
        address, /* account */
        address validator,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.installModule, (MODULE_TYPE_VALIDATOR, validator, initData)
        );
    }

    /**
     * get callData to uninstall validator on ERC7579 Account
     */
    function uninstallValidator(
        address account,
        address validator,
        bytes memory initData
    )
        internal
        view
        returns (bytes memory callData)
    {
        AccountType env = getAccountType();
        if (env == AccountType.DEFAULT || env == AccountType.SAFE) {
            // get previous validator in sentinel list
            address previous;

            (address[] memory array,) =
                IAccountModulesPaginated(account).getValidatorPaginated(address(0x1), 100);

            if (array.length == 1) {
                previous = address(0x1);
            } else if (array[0] == validator) {
                previous = address(0x1);
            } else {
                for (uint256 i = 1; i < array.length; i++) {
                    if (array[i] == validator) previous = array[i - 1];
                }
            }
            initData = abi.encode(previous, initData);
        }

        callData = abi.encodeCall(
            IERC7579Account.uninstallModule, (MODULE_TYPE_VALIDATOR, validator, initData)
        );
    }

    /**
     * get callData to install executor on ERC7579 Account
     */
    function installExecutor(
        address, /* account */
        address executor,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.installModule, (MODULE_TYPE_EXECUTOR, executor, initData)
        );
    }

    /**
     * get callData to uninstall executor on ERC7579 Account
     */
    function uninstallExecutor(
        address account,
        address executor,
        bytes memory initData
    )
        internal
        view
        returns (bytes memory callData)
    {
        AccountType env = getAccountType();
        if (env == AccountType.DEFAULT || env == AccountType.SAFE) {
            // get previous executor in sentinel list
            address previous;

            (address[] memory array,) =
                IAccountModulesPaginated(account).getExecutorsPaginated(address(0x1), 100);

            if (array.length == 1) {
                previous = address(0x1);
            } else if (array[0] == executor) {
                previous = address(0x1);
            } else {
                for (uint256 i = 1; i < array.length; i++) {
                    if (array[i] == executor) previous = array[i - 1];
                }
            }
            initData = abi.encode(previous, initData);
        }

        callData = abi.encodeCall(
            IERC7579Account.uninstallModule, (MODULE_TYPE_EXECUTOR, executor, initData)
        );
    }

    /**
     * get callData to install hook on ERC7579 Account
     */
    function installHook(
        address, /* account */
        address hook,
        bytes memory initData
    )
        internal
        view
        returns (bytes memory callData)
    {
        AccountType env = getAccountType();
        if (env == AccountType.SAFE) {
            callData = abi.encodeCall(
                IERC7579Account.installModule,
                (MODULE_TYPE_HOOK, hook, abi.encode(HookType.GLOBAL, bytes4(0x0), initData))
            );
        } else {
            callData =
                abi.encodeCall(IERC7579Account.installModule, (MODULE_TYPE_HOOK, hook, initData));
        }
    }

    /**
     * get callData to uninstall hook on ERC7579 Account
     */
    function uninstallHook(
        address, /* account */
        address hook,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.uninstallModule, (MODULE_TYPE_HOOK, address(0), initData)
        );
    }

    /**
     * get callData to install fallback on ERC7579 Account
     */
    function installFallback(
        address, /* account */
        address fallbackHandler,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(
            IERC7579Account.installModule, (MODULE_TYPE_FALLBACK, fallbackHandler, initData)
        );
    }

    /**
     * get callData to uninstall fallback on ERC7579 Account
     */
    function uninstallFallback(
        address, /* account */
        address fallbackHandler,
        bytes memory initData
    )
        internal
        pure
        returns (bytes memory callData)
    {
        fallbackHandler = fallbackHandler; //avoid solhint-no-unused-vars
        callData = abi.encodeCall(
            IERC7579Account.uninstallModule, (MODULE_TYPE_FALLBACK, address(0), initData)
        );
    }

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
        internal
        pure
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
    function encode(Execution[] memory executions) internal pure returns (bytes memory erc7579Tx) {
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
        internal
        pure
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

    function getNonce(
        address account,
        IEntryPoint entrypoint,
        address validator,
        address defaultValidator
    )
        internal
        view
        returns (uint256 nonce)
    {
        AccountType env = getAccountType();
        if (env == AccountType.KERNEL) {
            ValidationType vType;
            if (validator == defaultValidator) {
                vType = VALIDATION_TYPE_ROOT;
            } else {
                vType = VALIDATION_TYPE_VALIDATOR;
            }
            nonce = KernelHelpers.encodeNonce(vType, false, account, defaultValidator);
        } else {
            uint192 key = uint192(bytes24(bytes20(address(validator))));
            nonce = entrypoint.getNonce(address(account), key);
        }
    }
}
