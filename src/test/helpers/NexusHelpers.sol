// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { PackedUserOperation } from "../../external/ERC4337.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { HelperBase } from "./HelperBase.sol";
import { IAccountModulesPaginated } from "./interfaces/IAccountModulesPaginated.sol";
import { IERC1271, EIP1271_MAGIC_VALUE } from "src/Interfaces.sol";
import { CallType } from "src/accounts/common/lib/ModeLib.sol";

contract NexusHelpers is HelperBase {
    /*//////////////////////////////////////////////////////////////////////////
                                    USER OP
    //////////////////////////////////////////////////////////////////////////*/

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

    function makeNonceKey(bytes1 vMode, address validator) internal pure returns (uint192 key) {
        assembly {
            key := or(shr(88, vMode), validator)
        }
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
     * get callData to install fallback on ERC7579 Account
     */
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
        data = abi.encodePacked(selector, _initData);
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
}
