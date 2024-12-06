// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Types
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";
import {
    MODULE_TYPE_HOOK,
    MODULE_TYPE_VALIDATOR,
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_FALLBACK
} from "../../accounts/common/interfaces/IERC7579Module.sol";
import { HookType } from "../../accounts/safe/types/DataTypes.sol";
import { CALLTYPE_STATIC } from "../../accounts/common/lib/ModeLib.sol";
import { CallType } from "../../accounts/common/lib/ModeLib.sol";

// Dependencies
import { HelperBase } from "./HelperBase.sol";
import { SafeFactory } from "../../accounts/safe/SafeFactory.sol";

// Interfaces
import { ISafe7579Launchpad } from "../../accounts/safe/interfaces/ISafe7579Launchpad.sol";
import { IERC7579Account } from "../../accounts/common/interfaces/IERC7579Account.sol";
import { IAccountFactory } from "../../accounts/factory/interface/IAccountFactory.sol";
import { IAccountModulesPaginated } from "./interfaces/IAccountModulesPaginated.sol";
import { IERC1271, EIP1271_MAGIC_VALUE, IERC712 } from "../../Interfaces.sol";

// Utils
import { startPrank, stopPrank } from "../utils/Vm.sol";

/// @notice Helper functions for the Safe7579 implementation
contract SafeHelpers is HelperBase {
    /*//////////////////////////////////////////////////////////////////////////
                                       CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The typehash for EIP712 Safe messages
    bytes32 constant SAFE_MSG_TYPEHASH =
        0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;

    /*//////////////////////////////////////////////////////////////////////////
                                    EXECUTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Gets userOp and userOpHash for an executing calldata on an account instance
    /// @param instance AccountInstance the account instance to execute the callData on
    /// @param callData bytes the calldata to execute
    /// @param txValidator address the address of the validator
    /// @return userOp PackedUserOperation the user operation
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

    /// @notice Gets the data to install a validator on an account instance
    /// @param instance AccountInstance the account instance to install the validator on
    /// @param initData the data to pass to the validator
    /// @return data the data to install the validator
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

    /// @notice Gets the data to install an executor on an account instance
    /// @param instance AccountInstance the account instance to install the executor on
    /// @param initData the data to pass to the executor
    /// @return data the data to install the executor
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

    /// @notice Gets the data to install a hook on an account instance
    /// @param initData the data to pass to the hook
    /// @return data the data to install the hook
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

    /// @notice Gets the data to uninstall a hook on an account instance
    /// @param initData the data to pass to the hook
    /// @return data the data to uninstall the hook
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

    /// @notice Gets the data to install a fallback on an account instance
    /// @param initData the data to pass to the fallback
    /// @return data the data to install the fallback
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

    /// @notice Checks if a module is installed on an account instance
    /// @param instance AccountInstance the account instance to check
    /// @param moduleTypeId uint256 the type of the module
    /// @param module address the address of the module
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
            data = abi.encode(HookType.GLOBAL, bytes4(0x0), data);
        }

        return IERC7579Account(instance.account).isModuleInstalled(moduleTypeId, module, data);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SIGNATURE UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks if a signature is valid for an account instance
    /// @param instance AccountInstance the account instance to check the signature on
    /// @param validator address the address of the validator
    /// @param hash bytes32 the hash to check the signature against
    /// @param signature bytes the signature to check
    /// @return isValid bool whether the signature is valid, returns true if isValidSignature
    /// returns EIP1271_MAGIC_VALUE
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

    /// @notice Format a Safe compatible hash for an account instance
    /// @param instance AccountInstance the account instance to format the hash for
    /// @param hash bytes32 the hash to format
    /// @return bytes32 the formatted hash
    function formatERC1271Hash(
        AccountInstance memory instance,
        address validator,
        bytes32 hash
    )
        public
        virtual
        override
        deployAccountForAction(instance)
        returns (bytes32)
    {
        // Revert if validator is installed
        if (isModuleInstalled(instance, MODULE_TYPE_VALIDATOR, validator, "")) {
            revert("formatERC1271Hash: validator is installed");
        }
        bytes memory messageData = abi.encodePacked(
            bytes1(0x19),
            bytes1(0x01),
            IERC712(instance.account).domainSeparator(),
            keccak256(abi.encodePacked(SAFE_MSG_TYPEHASH, abi.encode(keccak256(abi.encode(hash)))))
        );
        return keccak256(messageData);
    }

    /// @notice Format a ERC1271 signature for an account
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
        return abi.encodePacked(validator, signature);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ACCOUNT UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Deploys an account instance if it has not been deployed yet
    ///         reverts if no initCode is provided
    /// @param instance AccountInstance the account instance to deploy
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

    /// @notice Gets the initCode and callData for a new account instance
    /// @param salt bytes32 the salt for the account instance
    /// @param txValidator address the address of the validator
    /// @param originalInitCode bytes the original initCode for the account instance
    /// @param erc4337CallData bytes the callData for the ERC4337 call
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
