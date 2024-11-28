// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { HelperBase } from "./HelperBase.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { ISafe7579Launchpad } from "src/accounts/safe/interfaces/ISafe7579Launchpad.sol";
import { SafeFactory } from "src/accounts/safe/SafeFactory.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";
import {
    MODULE_TYPE_HOOK,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK
} from "src/accounts/common/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "src/accounts/common/interfaces/IERC7579Account.sol";
import { HookType } from "src/accounts/safe/types/DataTypes.sol";
import { IAccountFactory } from "src/accounts/interface/IAccountFactory.sol";
import { IAccountModulesPaginated } from "./interfaces/IAccountModulesPaginated.sol";
import { CALLTYPE_STATIC } from "src/accounts/common/lib/ModeLib.sol";
import { IERC1271, EIP1271_MAGIC_VALUE } from "src/Interfaces.sol";
import { startPrank, stopPrank } from "../utils/Vm.sol";
import { CallType } from "src/accounts/common/lib/ModeLib.sol";

contract SafeHelpers is HelperBase {
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

        if (initCode.length != 0) {
            (initCode, callData) = _getInitCallData(instance.salt, txValidator, initCode, callData);
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

    /**
     * get callData to uninstall validator on ERC7579 Account
     */
    function getUninstallValidatorData(
        AccountInstance memory instance,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory data)
    {
        // get previous validator in sentinel list
        address previous;

        (address[] memory array,) =
            IAccountModulesPaginated(instance.account).getValidatorsPaginated(address(0x1), 100);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == module) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == module) previous = array[i - 1];
            }
        }
        data = abi.encode(previous, initData);
    }

    /**
     * get callData to uninstall executor on ERC7579 Account
     */
    function getUninstallExecutorData(
        AccountInstance memory instance,
        address module,
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory data)
    {
        // get previous executor in sentinel list
        address previous;

        (address[] memory array,) =
            IAccountModulesPaginated(instance.account).getExecutorsPaginated(address(0x1), 100);

        if (array.length == 1) {
            previous = address(0x1);
        } else if (array[0] == module) {
            previous = address(0x1);
        } else {
            for (uint256 i = 1; i < array.length; i++) {
                if (array[i] == module) previous = array[i - 1];
            }
        }
        data = abi.encode(previous, initData);
    }

    /**
     * get callData to install hook on ERC7579 Account
     */
    function getInstallHookData(
        AccountInstance memory, // instance
        address, // module
        bytes memory initData
    )
        public
        view
        virtual
        override
        returns (bytes memory data)
    {
        data = abi.encode(HookType.GLOBAL, bytes4(0x0), initData);
    }

    /**
     * get callData to uninstall hook on ERC7579 Account
     */
    function getUninstallHookData(
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
        data = abi.encode(HookType.GLOBAL, bytes4(0x0), initData);
    }

    /**
     * get callData to uninstall fallback on ERC7579 Account
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
        data = abi.encode(selector, _initData);
    }

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
            callData = abi.encodeCall(IERC7579Account.installModule, (moduleType, module, initData));
        } else {
            initData = getUninstallModuleData({
                instance: instance,
                moduleType: moduleType,
                module: module,
                initData: initData
            });
            callData =
                abi.encodeCall(IERC7579Account.uninstallModule, (moduleType, module, initData));
        }

        if (initCode.length != 0) {
            (initCode, callData) = _getInitCallData(instance.salt, txValidator, initCode, callData);
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
            data = abi.encode(HookType.GLOBAL, bytes4(0x0), data);
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
            hash, abi.encodePacked(validator, signature)
        ) == EIP1271_MAGIC_VALUE;
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
        return abi.encodePacked(validator, signature);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ACCOUNT UTILS
    //////////////////////////////////////////////////////////////////////////*/

    function deployAccount(AccountInstance memory instance) public virtual override {
        if (instance.account.code.length == 0) {
            if (instance.initCode.length == 0) {
                revert("deployAccount: no initCode provided");
            } else {
                (bytes memory initCode, bytes memory callData) = _getInitCallData(
                    instance.salt,
                    address(instance.defaultValidator),
                    instance.initCode,
                    encode({ target: address(1), value: 1 wei, callData: "" })
                );
                assembly {
                    let factory := mload(add(initCode, 20))
                    let success := call(gas(), factory, 0, add(initCode, 52), mload(initCode), 0, 0)
                    if iszero(success) { revert(0, 0) }
                }
                PackedUserOperation memory userOp = PackedUserOperation({
                    sender: instance.account,
                    nonce: getNonce(instance, callData, address(instance.defaultValidator)),
                    initCode: "",
                    callData: callData,
                    accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
                    preVerificationGas: 2e6,
                    gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
                    paymasterAndData: bytes(""),
                    signature: bytes("")
                });
                bytes32 userOpHash = instance.aux.entrypoint.getUserOpHash(userOp);
                bytes memory userOpValidationCallData =
                    abi.encodeCall(ISafe7579Launchpad.validateUserOp, (userOp, userOpHash, 0));
                startPrank(address(instance.aux.entrypoint));
                (bool success,) = instance.account.call(userOpValidationCallData);
                if (!success) {
                    revert("deployAccount: failed to call account");
                }

                (success,) = instance.account.call(callData);

                if (!success) {
                    revert("deployAccount: failed to call account");
                }
                stopPrank();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTERNAL
    //////////////////////////////////////////////////////////////////////////*/

    function _getInitCallData(
        bytes32 salt,
        address txValidator,
        bytes memory originalInitCode,
        bytes memory erc4337CallData
    )
        public
        returns (bytes memory initCode, bytes memory callData)
    {
        // TODO: refactor this to decode the initcode
        address factory;
        assembly {
            factory := mload(add(originalInitCode, 20))
        }
        ISafe7579Launchpad.InitData memory initData = abi.decode(
            IAccountFactory(factory).getInitData(txValidator, ""), (ISafe7579Launchpad.InitData)
        );
        initData.callData = erc4337CallData;
        initCode = abi.encodePacked(
            factory, abi.encodeCall(SafeFactory.createAccount, (salt, abi.encode(initData)))
        );
        callData = abi.encodeCall(ISafe7579Launchpad.setupSafe, (initData));
    }
}
