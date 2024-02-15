// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AccountInstance, UserOpData } from "./RhinestoneModuleKit.sol";
import { IERC7579Account, Execution, MODULE_TYPE_FALLBACK } from "../external/ERC7579.sol";
import { ERC7579Helpers } from "./utils/ERC7579Helpers.sol";
import { ExtensibleFallbackHandler } from "../core/ExtensibleFallbackHandler.sol";
import { ModuleKitUserOp } from "./ModuleKitUserOp.sol";
import { ModuleKitHelpers } from "./ModuleKitHelpers.sol";

library ModuleKitFallbackHandler {
    using ModuleKitUserOp for AccountInstance;
    using ModuleKitHelpers for AccountInstance;
    /**
     * @dev Installs ExtensibleFallbackHandler on the account if not already installed, and
     * configures
     *
     * @param instance AccountInstance
     * @param handleFunctionSig function sig that should be handled
     * @param isStatic is function staticcall or call
     * @param subHandler ExtensibleFallbackHandler subhandler to handle this function sig
     */

    function installFallback(
        AccountInstance memory instance,
        bytes4 handleFunctionSig,
        bool isStatic,
        address subHandler
    )
        internal
        returns (UserOpData memory userOpData)
    {
        // check if fallbackhandler is installed on account

        bool enabled =
            instance.isModuleInstalled(MODULE_TYPE_FALLBACK, address(instance.aux.fallbackHandler));

        Execution[] memory executions;

        if (!enabled) {
            // length: 2 (install of ExtensibleFallbackHandler + configuration of subhandler)
            executions = new Execution[](2);

            //  get Execution struct to install ExtensibleFallbackHandler on account
            executions[0] = Execution({
                target: instance.account,
                value: 0,
                callData: ERC7579Helpers.configModule(
                    instance.account,
                    MODULE_TYPE_FALLBACK,
                    address(instance.aux.fallbackHandler), // ExtensibleFallbackHandler from Auxiliary
                    "",
                    ERC7579Helpers.installModule // <--
                )
            });
        } else {
            // length: 1 (configuration of subhandler. ExtensibleFallbackHandler is already
            // installed as the FallbackHandler on the Account)
            executions = new Execution[](1);
        }

        // Follow ExtensibleFallbackHandler ABI
        ExtensibleFallbackHandler.FallBackType fallbackType = isStatic
            ? ExtensibleFallbackHandler.FallBackType.Static
            : ExtensibleFallbackHandler.FallBackType.Dynamic;
        ExtensibleFallbackHandler.Params memory params = ExtensibleFallbackHandler.Params({
            selector: handleFunctionSig,
            fallbackType: fallbackType,
            handler: subHandler
        });

        // set the function selector on the ExtensibleFallbackHandler
        // using executions.length -1 here because we want this to be the last execution
        executions[executions.length - 1] = Execution({
            target: address(instance.aux.fallbackHandler),
            value: 0,
            callData: abi.encodeCall(ExtensibleFallbackHandler.setFunctionSig, (params))
        });

        userOpData = instance.getExecOps({
            executions: executions,
            txValidator: address(instance.defaultValidator)
        });
    }
}
