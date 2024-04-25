// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.25;

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { ERC7579HookDestructWithData, Execution } from "./Destruct.sol";
import { IERC3156FlashLender } from "modulekit/src/interfaces/Flashloan.sol";
import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";
import { HookMultiPlexerBase } from "./HookMultiPlexerBase.sol";
import "./DataTypes.sol";
import { IERC7579Account } from "modulekit/src/external/ERC7579.sol";

contract HookMultiPlexer is ERC7579HookDestructWithData, HookMultiPlexerBase {
    function onInstall(bytes calldata data) external override {
        Config storage $config = $getConfig(msg.sender);
        (
            IERC7579Hook[] memory globalHooks,
            IERC7579Hook[] memory valueHooks,
            IERC7579Hook[] memory sigHooks
        ) = abi.decode(data, (IERC7579Hook[], IERC7579Hook[], IERC7579Hook[]));

        $config.globalHooks = globalHooks;
        $config.valueHooks = valueHooks;
        // $config.sigHooks = sigHooks;
    }

    function onUninstall(bytes calldata) external override { }
    /**
     * Execute function was called on the account
     * @dev this function will revert as the module does not allow direct execution
     */

    function onExecute(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData,
        bytes calldata msgData
    )
        internal
        virtual
        override
        returns (bytes memory context)
    {
        context = _handleSingle(IERC7579Account.execute.selector, msgSender, value, msgData);
    }

    /**
     * ExecuteBatch function was called on the account
     * @dev this function will revert as the module does not allow direct execution
     */
    function onExecuteBatch(
        address msgSender,
        Execution[] calldata executions,
        bytes calldata msgData
    )
        internal
        virtual
        override
        returns (bytes memory context)
    {
        context = _handleBatch(IERC7579Account.execute.selector, msgSender, executions, msgData);
    }

    /**
     * Execute from executor function was called on the account
     * @dev this function will revert as the module does not allow direct execution
     *
     * @param target address of the target
     * @param value value to be sent by account
     * @param callData data to be sent by account
     */
    function onExecuteFromExecutor(
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData,
        bytes calldata msgData
    )
        internal
        virtual
        override
        returns (bytes memory context)
    {
        context =
            _handleSingle(IERC7579Account.executeFromExecutor.selector, msgSender, value, msgData);
    }

    /**
     * ExecuteBatch from executor function was called on the account
     * @dev this function will revert as the module does not allow batched executions from executor
     */
    function onExecuteBatchFromExecutor(
        address msgSender,
        Execution[] calldata executions,
        bytes calldata msgData
    )
        internal
        virtual
        override
        returns (bytes memory context)
    {
        context = _handleBatch(
            IERC7579Account.executeFromExecutor.selector, msgSender, executions, msgData
        );
    }

    /**
     * InstallModule function was called on the account
     * @dev install module calls need to be timelocked
     *
     * @param moduleTypeId type of the module
     * @param module address of the module
     * @param initData data to be passed to the module
     */
    function onInstallModule(
        address msgSender,
        uint256 moduleTypeId,
        address module,
        bytes calldata initData,
        bytes calldata msgData
    )
        internal
        virtual
        override
        returns (bytes memory context)
    {
        context = _handleSingle(IERC7579Account.installModule.selector, msgSender, 0, msgData);
    }

    /**
     * UninstallModule function was called on the account
     * @dev install module calls need to be timelocked
     *
     * @param moduleTypeId type of the module
     * @param module address of the module
     * @param deInitData data to be passed to the module
     */
    function onUninstallModule(
        address msgSender,
        uint256 moduleTypeId,
        address module,
        bytes calldata deInitData,
        bytes calldata msgData
    )
        internal
        virtual
        override
        returns (bytes memory context)
    {
        context = _handleSingle(IERC7579Account.uninstallModule.selector, msgSender, 0, msgData);
    }

    /**
     * Unknown function was called on the account
     * @dev This function will revert except when used for flashloans
     *
     * @param msgSender address of the sender
     * @param callData data passed to the account
     *
     * @return context bytes encoded data
     */
    function onUnknownFunction(
        address msgSender,
        uint256 value,
        bytes calldata callData,
        bytes calldata msgData
    )
        internal
        virtual
        returns (bytes memory context)
    {
        context = _handleSingle(bytes4(callData[:4]), msgSender, 0, msgData);
    }

    function onPostCheck(bytes calldata hookData) internal virtual override {
        AllContext memory context = abi.decode(hookData, (AllContext));

        for (uint256 i; i < context.globalHooks.length; i++) {
            context.globalHooks[i].subHook.postCheck(context.globalHooks[i].context);
        }
        for (uint256 i; i < context.valueHooks.length; i++) {
            context.valueHooks[i].subHook.postCheck(context.valueHooks[i].context);
        }
        for (uint256 i; i < context.sigHooks.length; i++) {
            context.sigHooks[i].subHook.postCheck(context.sigHooks[i].context);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/
    /**
     * Returns the type of the module
     *
     * @param typeID type of the module
     *
     * @return true if the type is a module type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure virtual override returns (bool) {
        return typeID == TYPE_HOOK;
    }

    /**
     * Returns the name of the module
     *
     * @return name of the module
     */
    function name() external pure virtual returns (string memory) {
        return "HookMultiPlexer";
    }

    /**
     * Returns the version of the module
     *
     * @return version of the module
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.2";
    }

    function isInitialized(address smartAccount) public view returns (bool) { }
}
