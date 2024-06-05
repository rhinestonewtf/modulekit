// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution, IERC7579Account } from "../../external/ERC7579.sol";
import "erc7579/lib/ModeLib.sol";
import "erc7579/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import "../utils/Vm.sol";
import { IAccountHelpers } from "./IAccountHelpers.sol";
import { IAccountModulesPaginated } from "./IAccountModulesPaginated.sol";

contract HelperBase is IAccountHelpers {
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
        public
        view
        virtual
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
        public
        pure
        virtual
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
        public
        view
        virtual
        returns (bytes memory callData)
    {
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
        public
        pure
        virtual
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
        public
        view
        virtual
        returns (bytes memory callData)
    {
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
        public
        view
        virtual
        returns (bytes memory callData)
    {
        callData = abi.encodeCall(IERC7579Account.installModule, (MODULE_TYPE_HOOK, hook, initData));
    }

    /**
     * get callData to uninstall hook on ERC7579 Account
     */
    function uninstallHook(
        address, /* account */
        address, /*hook*/
        bytes memory initData
    )
        public
        pure
        virtual
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
        public
        pure
        virtual
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
        public
        pure
        virtual
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

    function getNonce(
        AccountInstance memory instance,
        bytes memory,
        address txValidator
    )
        public
        view
        virtual
        returns (uint256 nonce)
    {
        uint192 key = uint192(bytes24(bytes20(address(txValidator))));
        nonce = instance.aux.entrypoint.getNonce(address(instance.account), key);
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
        return IERC7579Account(instance.account).isModuleInstalled(moduleTypeId, module, data);
    }

    function getInstallModuleData(
        AccountInstance memory,
        uint256,
        address,
        bytes memory data
    )
        public
        view
        virtual
        override
        returns (bytes memory)
    {
        return data;
    }

    function getUninstallModuleData(
        AccountInstance memory,
        uint256,
        address,
        bytes memory data
    )
        public
        view
        virtual
        override
        returns (bytes memory)
    {
        return data;
    }
}
