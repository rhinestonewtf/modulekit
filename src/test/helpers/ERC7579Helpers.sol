// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution, IERC7579Account } from "../../external/ERC7579.sol";
import "erc7579/lib/ModeLib.sol";
import "erc7579/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import "../utils/Vm.sol";
import { HelperBase } from "./HelperBase.sol";
import { IAccountModulesPaginated } from "./interfaces/IAccountModulesPaginated.sol";

contract ERC7579Helpers is HelperBase {
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
        override
        returns (bytes memory data)
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
        data = abi.encode(previous, initData);
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
        override
        returns (bytes memory data)
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
        data = abi.encode(previous, initData);
    }
}
