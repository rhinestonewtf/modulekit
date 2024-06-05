// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution, IERC7579Account } from "../../external/ERC7579.sol";
import "erc7579/lib/ModeLib.sol";
import "erc7579/interfaces/IERC7579Module.sol";
import { PackedUserOperation } from "../../external/ERC4337.sol";
import { AccountInstance } from "../RhinestoneModuleKit.sol";
import "../utils/Vm.sol";
import { HelperBase } from "./HelperBase.sol";
import { IAccountModulesPaginated } from "./IAccountModulesPaginated.sol";

contract ERC7579Helpers is HelperBase {
    /**
     * get callData to uninstall hook on ERC7579 Account
     */
    function uninstallHook(
        address, /* account */
        address hook,
        bytes memory initData
    )
        public
        pure
        virtual
        override
        returns (bytes memory callData)
    {
        callData =
            abi.encodeCall(IERC7579Account.uninstallModule, (MODULE_TYPE_HOOK, hook, initData));
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
        override
        returns (bytes memory callData)
    {
        fallbackHandler = fallbackHandler; //avoid solhint-no-unused-vars
        callData = abi.encodeCall(
            IERC7579Account.uninstallModule, (MODULE_TYPE_FALLBACK, fallbackHandler, initData)
        );
    }
}
