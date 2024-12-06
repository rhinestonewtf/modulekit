// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Types
import { PackedUserOperation } from "../../external/ERC4337.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { CallType } from "../../accounts/common/lib/ModeLib.sol";

// Interfaces
import { IAccountModulesPaginated } from "./interfaces/IAccountModulesPaginated.sol";
import { IERC1271, EIP1271_MAGIC_VALUE } from "../../Interfaces.sol";

// Dependencies
import { HelperBase } from "./HelperBase.sol";

/// @notice Helper functions for the Nexus ERC7579 implementation
contract NexusHelpers is HelperBase {
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
        view
        override
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        bool notDeployedYet = instance.account.code.length == 0;
        if (notDeployedYet) {
            initCode = instance.initCode;
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(instance, 0x00, txValidator),
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

    /*//////////////////////////////////////////////////////////////
                                 NONCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the nonce for an account instance
    /// @param instance AccountInstance the account instance to get the nonce for
    /// @param vMode bytes1 the mode of the validator
    /// @param validator address the address of the validator
    /// @return nonce uint256 the nonce
    function getNonce(
        AccountInstance memory instance,
        bytes1 vMode,
        address validator
    )
        internal
        view
        returns (uint256 nonce)
    {
        uint192 key = makeNonceKey(vMode, validator);
        nonce = instance.aux.entrypoint.getNonce(address(instance.account), key);
    }

    /// @notice Makes a nonce key for an account instance
    /// @param vMode bytes1 the mode of the validator
    /// @param validator address the address of the validator
    function makeNonceKey(bytes1 vMode, address validator) internal pure returns (uint192 key) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            key := or(shr(88, vMode), validator)
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    MODULE CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Configures a userop for an account instance to install or uninstall a module
    /// @param instance AccountInstance the account instance to configure the userop for
    /// @param moduleType uint256 the type of the module
    /// @param module address the address of the module
    /// @param initData data the data to pass to the module
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
        view
        override
        returns (PackedUserOperation memory userOp, bytes32 userOpHash)
    {
        bytes memory initCode;
        if (instance.account.code.length == 0) {
            initCode = instance.initCode;
        }
        bytes memory callData;
        if (isInstall) {
            initData = getInstallModuleData(instance, moduleType, module, initData);
            callData = getInstallModuleCallData(instance, moduleType, module, initData);
        } else {
            initData = getUninstallModuleData(instance, moduleType, module, initData);
            callData = getUninstallModuleCallData(instance, moduleType, module, initData);
        }

        userOp = PackedUserOperation({
            sender: instance.account,
            nonce: getNonce(instance, 0x00, txValidator),
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

    /// @notice Gets the data to install a validator on an account instance
    /// @param instance AccountInstance the account instance to install the validator on
    /// @param initData the data to pass to the validator
    /// @return data the data to install the validator
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

    /// @notice Gets the data to install a fallback on an account instance
    /// @param initData the data to pass to the module
    /// @return data the data to install the fallback
    function getInstallFallbackData(
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
        (bytes4 selector, CallType callType, bytes memory _initData) =
            abi.decode(initData, (bytes4, CallType, bytes));
        data = abi.encodePacked(selector, callType, _initData);
    }

    /// @notice Gets the data to uninstall a fallback on an account instance
    /// @param initData the data to pass to the module
    /// @return data the data to uninstall the fallback
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

    /*//////////////////////////////////////////////////////////////////////////
                                SIGNATURE UTILS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks if a signature is valid for an account instance
    /// @param instance AccountInstance the account instance to check the signature on
    /// @param validator address the address of the validator
    /// @param hash bytes32 the hash of the data that is signed
    /// @param signature bytes the signature to check
    /// @return isValid bool whether the signature is valid, return true if isValidSignature return
    /// EIP1271_MAGIC_VALUE
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

    /// @notice Formats an ERC1271 signature for an account instance
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
}
