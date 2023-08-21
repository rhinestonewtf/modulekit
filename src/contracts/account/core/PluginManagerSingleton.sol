// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SentinelListLib} from "sentinellist/src/SentinelList.sol";
import "../../modules/plugin/IPluginBase.sol";
import "./RegistryAdapter.sol";

abstract contract PluginManager is RegistryAdapter {
    using SentinelListLib for SentinelListLib.SentinelList;

    address internal constant SENTINEL_MODULES = address(0x1);

    mapping(address account => mapping(address plugin => PluginAccessInfo)) public enabledPlugins;

    struct PluginAccessInfo {
        bool rootAddressGranted;
        address nextPluginPointer;
    }

    modifier onlyPlugin(address account) {
        bool pluginEnabled = isPluginEnabled({account: account, plugin: msg.sender});
        if (!pluginEnabled) revert PluginNotEnabled(msg.sender);

        _enforceRegistryCheck(msg.sender);
        _;
    }

    modifier checkRegistry(address plugin) {
        _enforceRegistryCheck(plugin);
        _;
    }

    modifier onlyEnabledPlugin(address safe) {
        if (enabledPlugins[safe][msg.sender].nextPluginPointer == address(0)) {
            revert PluginNotEnabled(msg.sender);
        }
        _;
    }

    modifier noZeroOrSentinelPlugin(address plugin) {
        if (plugin == address(0) || plugin == SENTINEL_MODULES) {
            revert InvalidPluginAddress(plugin);
        }
        _;
    }

    function setTrustedAttester(address attester) external {
        _setAttester(msg.sender, attester);
    }
    /**
     * @notice Called by a Safe to enable a plugin on a Safe. To be called by a safe.
     * @param plugin ISafeProtocolPlugin A plugin that has to be enabled
     * @param allowRootAccess Bool indicating whether root access to be allowed.
     */

    function enablePlugin(address plugin, bool allowRootAccess)
        external
        noZeroOrSentinelPlugin(plugin)
        checkRegistry(plugin)
    {
        PluginAccessInfo storage senderSentinelPlugin = enabledPlugins[msg.sender][SENTINEL_MODULES];
        PluginAccessInfo storage senderPlugin = enabledPlugins[msg.sender][plugin];

        if (senderPlugin.nextPluginPointer != address(0)) {
            revert PluginAlreadyEnabled(msg.sender, plugin);
        }

        if (senderSentinelPlugin.nextPluginPointer == address(0)) {
            senderSentinelPlugin.rootAddressGranted = false;
            senderSentinelPlugin.nextPluginPointer = SENTINEL_MODULES;
        }

        senderPlugin.nextPluginPointer = senderSentinelPlugin.nextPluginPointer;
        senderPlugin.rootAddressGranted = false;
        senderSentinelPlugin.nextPluginPointer = plugin;

        emit PluginEnabled(msg.sender, plugin);
    }
    /**
     * @notice Disable a plugin. This function should be called by Safe.
     * @param plugin Plugin to be disabled
     */

    function disablePlugin(address prevPlugin, address plugin) external noZeroOrSentinelPlugin(plugin) {
        PluginAccessInfo storage prevPluginInfo = enabledPlugins[msg.sender][prevPlugin];
        PluginAccessInfo storage pluginInfo = enabledPlugins[msg.sender][plugin];

        if (prevPluginInfo.nextPluginPointer != plugin) {
            revert InvalidPrevPluginAddress(prevPlugin);
        }

        prevPluginInfo.nextPluginPointer = pluginInfo.nextPluginPointer;
        prevPluginInfo.rootAddressGranted = pluginInfo.rootAddressGranted;

        pluginInfo.nextPluginPointer = address(0);
        pluginInfo.rootAddressGranted = false;
        emit PluginDisabled(msg.sender, plugin);
    }
    /**
     * @notice Returns if an plugin is enabled
     * @return True if the plugin is enabled
     */

    function isPluginEnabled(address account, address plugin) public view returns (bool) {
        return SENTINEL_MODULES != plugin && enabledPlugins[account][plugin].nextPluginPointer != address(0);
    }

    function executeTransaction(address account, PluginTransaction calldata transaction)
        external
        onlyPlugin(account)
        returns (bytes[] memory data)
    {
        // Initialize a new array of bytes with the same length as the transaction actions
        uint256 length = transaction.actions.length;
        data = new bytes[](length);

        // Loop through all the actions in the transaction
        for (uint256 i; i < length; ++i) {
            address to = transaction.actions[i].to;
            PluginAction calldata safeProtocolAction = transaction.actions[i];

            // revert if plugin is calling a transaction on avatar or manager
            if (to == address(this) || to == account) {
                revert InvalidToFieldInSafeProtocolAction(account, bytes32(0), 0);
            }

            // Execute the action and store the success status and returned data
            (bool isActionSuccessful, bytes memory resultData) = _execTransationOnSmartAccount(
                account, safeProtocolAction.to, safeProtocolAction.value, safeProtocolAction.data
            );

            // If the action was not successful, revert the transaction
            if (!isActionSuccessful) {
                revert ActionExecutionFailed(account, transaction.metadataHash, i);
            } else {
                data[i] = resultData;
            }
        }
    }

    /**
     * @notice Returns an array of plugins enabled for a Safe address.
     *         If all entries fit into a single page, the next pointer will be 0x1.
     *         If another page is present, next will be the last element of the returned array.
     * @param start Start of the page. Has to be a plugin or start pointer (0x1 address)
     * @param pageSize Maximum number of plugins that should be returned. Has to be > 0
     * @return array Array of plugins.
     * @return next Start of the next page.
     */
    function getPluginsPaginated(address start, uint256 pageSize, address safe)
        external
        view
        returns (address[] memory array, address next)
    {
        if (pageSize == 0) {
            revert ZeroPageSizeNotAllowed();
        }

        if (!(start == SENTINEL_MODULES || isPluginEnabled(safe, start))) {
            revert InvalidPluginAddress(start);
        }
        // Init array with max page size
        array = new address[](pageSize);

        // Populate return array
        uint256 pluginCount = 0;
        next = enabledPlugins[safe][start].nextPluginPointer;
        while (next != address(0) && next != SENTINEL_MODULES && pluginCount < pageSize) {
            array[pluginCount] = next;
            next = enabledPlugins[safe][next].nextPluginPointer;
            pluginCount++;
        }

        // This check is required because the enabled plugin list might not be initialised yet. e.g. no enabled plugins for a safe ever before
        if (pluginCount == 0) {
            next = SENTINEL_MODULES;
        }

        /**
         * Because of the argument validation, we can assume that the loop will always iterate over the valid plugin list values
         *       and the `next` variable will either be an enabled plugin or a sentinel address (signalling the end).
         *
         *       If we haven't reached the end inside the loop, we need to set the next pointer to the last element of the plugins array
         *       because the `next` variable (which is a plugin by itself) acting as a pointer to the start of the next page is neither
         *       included to the current page, nor will it be included in the next one if you pass it as a start.
         */
        if (next != SENTINEL_MODULES && pluginCount != 0) {
            next = array[pluginCount - 1];
        }
        // Set correct size of returned array
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(array, pluginCount)
        }
    }

    function _execTransationOnSmartAccount(address account, address to, uint256 value, bytes memory data)
        internal
        virtual
        returns (bool, bytes memory);

    event PluginEnabled(address indexed account, address indexed plugin);
    event PluginDisabled(address indexed account, address indexed plugin);

    error PluginRequiresRootAccess(address sender);
    error PluginNotEnabled(address plugin);
    error PluginEnabledOnlyForRootAccess(address plugin);
    error PluginAccessMismatch(address plugin, bool requiresRootAccess, bool providedValue);
    error ActionExecutionFailed(address safe, bytes32 metadataHash, uint256 index);
    error RootAccessActionExecutionFailed(address safe, bytes32 metadataHash);
    error PluginAlreadyEnabled(address safe, address plugin);
    error InvalidPluginAddress(address plugin);
    error InvalidToFieldInSafeProtocolAction(address account, bytes32 metadataHash, uint256 index);
    error InvalidPrevPluginAddress(address plugin);
    error ZeroPageSizeNotAllowed();
}
