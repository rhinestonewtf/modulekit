// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

// Types
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import { CallType } from "../../accounts/common/lib/ModeLib.sol";

// Dependencies
import { HelperBase } from "./HelperBase.sol";

// Interfaces
import { IAccountModulesPaginated } from "./interfaces/IAccountModulesPaginated.sol";
import { IERC1271, EIP1271_MAGIC_VALUE } from "../../Interfaces.sol";

/// @notice Helper functions for ERC7579 reference implementation based Accounts
contract ERC7579Helpers is HelperBase {
    /*//////////////////////////////////////////////////////////////////////////
                                    MODULE CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice get callData to uninstall a validator on an ERC7579 Account
    /// @param instance AccountInstance the account instance to uninstall the validator from
    /// @param module address the address of the module to uninstall
    /// @param initData bytes the data to pass to the module
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

    /// @notice get callData to install a validator on an ERC7579 Account
    /// @param instance AccountInstance the account instance to install the validator on
    /// @param module address the address of the module to install
    /// @param initData bytes the data to pass to the module
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

    /// @notice get callData to install a fallback on an ERC7579 Account
    /// @param initData bytes the data to pass to the module
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

    /// @notice get callData to uninstall a fallback on an ERC7579 Account
    /// @param initData bytes the data to pass to the module
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

    /// @notice Check if a signature is valid for an account, returns true if isValidSignature
    /// returns EIP1271_MAGIC_VALUE
    /// @param instance AccountInstance the account instance to check the signature on
    /// @param validator address the address of the validator
    /// @param hash bytes32 the hash to check the signature against
    /// @param signature bytes the signature to check
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

    /// @notice Format a ERC1271 signature for an account
    /// @param validator address the address of the validator
    /// @param signature bytes the signature to format
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
