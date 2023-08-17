// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "../../auxiliary/interfaces/IPluginBase.sol";
import {IProtocolFactory} from "../../auxiliary/interfaces/IProtocolFactory.sol";

import {MinimalProxyUtil} from "../lib/MinimalProxyUtil.sol";

import "forge-std/console2.sol";

abstract contract ModuleManager {
    // Instance of the IProtocolFactory contract
    IProtocolFactory cloneFactory;

    // Sentinel value used to denote the start/end of a linked list of plugins
    address internal constant SENTINEL_PLUGINS = address(0x1);

    // Mapping to keep track of the access info for each plugin
    mapping(address => PluginAccessInfo) public enabledPlugins;

    // Mapping to keep track of clone contracts. The key is a combination of the plugin implementation and a unique salt.
    mapping(address pluginImpl => mapping(bytes32 salt => address clone)) public pluginImplToClones;

    struct PluginAccessInfo {
        // ----------------------Metadata----------------------
        bool rootAddressGranted; //1
        bool cloned; // 1
        // ----------------------Operators----------------------
        address nextPluginPointer; //20
    }

    /**
     * @dev Initializes the Module Manager.
     *
     * @notice This function is used to initialize the Module Manager with the registry, trusted authority, and clone factory contracts.
     * The registry contract is an instance of the IRSQuery interface that manages the registry of plugins.
     * The trusted authority is the address of the contract that will be the trusted authority.
     * The clone factory contract is an instance of the ICloneFactory interface which is responsible for creating clone contracts.
     *
     */
    function _initializeModuleManager(address _cloneFactory) internal {
        cloneFactory = IProtocolFactory(_cloneFactory);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier that ensures that the caller is a plugin or a plugin clone.
     *
     * @notice Checks whether the plugin is enabled and permitted, meaning it has not been flagged by the trusted authority.
     * If the plugin has been cloned, it gets the implementation of the clone.
     *
     * @param plugin The address of the plugin contract.
     *
     */
    modifier onlyPluginOrClone(address plugin) {
        PluginAccessInfo memory pluginAccessInfo = enabledPlugins[plugin];

        bool pluginEnabled = isPluginEnabled({plugin: plugin, pluginAccessInfo: pluginAccessInfo});
        if (!pluginEnabled) revert PluginNotEnabled(plugin);

        // If plugin is a clone, get the implementation address of the proxy bytecode
        // and overwrite plugin variable with the implementation address
        plugin = pluginAccessInfo.cloned ? MinimalProxyUtil.getImpl(plugin) : plugin;

        // check plugin implementation address on registry
        _enforceRegistryCheck(plugin);
        _;
    }

    /**
     * @dev Modifier that ensures that the caller is a permitted plugin.
     *
     * @notice Checks whether the plugin is registered and not flagged by the trusted authority.
     * If the plugin has been cloned, it gets the implementation of the clone.
     *
     * @param plugin The address of the plugin contract.
     *
     */
    modifier onlyPermittedPlugin(address plugin) {
        // Only allow registered and non-flagged plugins

        // If plugin is a clone, get the implementation address of the proxy bytecode
        // and overwrite plugin variable with the implementation address
        address pluginImpl = enabledPlugins[plugin].cloned ? MinimalProxyUtil.getImpl(plugin) : plugin;

        _enforceRegistryCheck(pluginImpl);
        _;
    }

    /**
     * @dev Modifier that ensures that the caller is an enabled module.
     *
     * @notice Checks whether the module is enabled.
     *
     * @param module The address of the module.
     *
     */
    modifier onlyEnabledModule(address module) {
        if (!isPluginEnabled(module)) revert PluginNotEnabled(module);
        _;
    }

    /**
     * @dev Modifier that ensures that the address is not zero or the sentinel plugin.
     *
     * @notice Checks whether the address is zero or the sentinel plugin.
     * These addresses are not valid for plugins.
     *
     * @param plugin The address of the plugin contract.
     *
     */
    modifier noZeroOrSentinelPlugin(address plugin) {
        if (plugin == address(0) || plugin == SENTINEL_PLUGINS) {
            revert InvalidPluginAddress(plugin);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CLONE PLUGIN
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev function that clones a plugin by using the clone factory implemented in the protocol
     *
     * @notice this function should be used if the plugin does not require any initializion
     *
     * @param _pluginImpl The address of the plugin contract.
     * @param _salt user provided salt
     */
    function _clonePlugin(address _pluginImpl, bytes32 _salt) internal returns (address clone) {
        clone = cloneFactory.clonePlugin(_pluginImpl, _salt);
        pluginImplToClones[_pluginImpl][_salt] = clone;
    }

    /**
     * @dev function that clones a plugin by using the clone factory implemented in the protocol
     *
     * @notice this function should be used if the plugin does not require any initializion
     *
     * @param _pluginImpl The address of the plugin contract.
     * @param _initCallData The data to be used in the initialization call.
     * @param _salt user provided salt
     */
    function _clonePlugin(address _pluginImpl, bytes memory _initCallData, bytes32 _salt)
        internal
        returns (address clone)
    {
        bytes32 deploymentSalt;
        (clone, deploymentSalt) = cloneFactory.clonePlugin(_pluginImpl, _initCallData, _salt);

        pluginImplToClones[_pluginImpl][deploymentSalt] = clone;
    }

    /*//////////////////////////////////////////////////////////////
                              PLUGIN EXECUTIONS
    //////////////////////////////////////////////////////////////*/

    function executeTransaction(PluginTransaction calldata transaction)
        external
        onlyPluginOrClone(msg.sender)
        returns (bytes[] memory data)
    {
        // Initialize a new array of bytes with the same length as the transaction actions
        uint256 length = transaction.actions.length;
        data = new bytes[](length);

        // Loop through all the actions in the transaction
        for (uint256 i; i < length; ++i) {
            PluginAction calldata safeProtocolAction = transaction.actions[i];

            // revert if plugin is calling a transaction on avatar or manager
            _rejectCalltoAccountOrManager({to: safeProtocolAction.to});

            // Execute the action and store the success status and returned data
            (bool isActionSuccessful, bytes memory resultData) =
                _execTransationOnSmartAccount(safeProtocolAction.to, safeProtocolAction.value, safeProtocolAction.data);

            // If the action was not successful, revert the transaction
            if (!isActionSuccessful) {
                revert ActionExecutionFailed(_accountAddress(), transaction.metadataHash, i);
            } else {
                data[i] = resultData;
            }
        }
    }

    function executeRootAction(PluginRootAccess calldata rootAccess)
        external
        onlyPluginOrClone(msg.sender)
        returns (bytes memory data)
    {
        PluginAction calldata transaction = rootAccess.action;

        // Check if the plugin contract requires root access and if it has been granted root access
        if (!IPluginBase(msg.sender).requiresRootAccess() || !enabledPlugins[msg.sender].rootAddressGranted) {
            revert PluginRequiresRootAccess(msg.sender);
        }

        // Delegate the transaction call
        bool success;
        (success, data) = _execDelegateCallOnSmartAccount(transaction.to, transaction.value, transaction.data);

        // Emit an event if the transaction is successful, otherwise revert
        if (success) {
            emit RootAccessActionExecuted(_accountAddress(), rootAccess.metadataHash);
        } else {
            revert RootAccessActionExecutionFailed(_accountAddress(), rootAccess.metadataHash);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              PLUGIN MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Called by a Safe to enable a plugin on a Safe. To be called by a safe.
     * @param plugin IPluginBase A plugin that has to be enabled
     * @param allowRootAccess Bool indicating whether root access to be allowed.
     */
    function _enablePlugin(address plugin, bool allowRootAccess)
        internal
        noZeroOrSentinelPlugin(plugin)
        onlyPermittedPlugin(plugin)
    {
        PluginAccessInfo storage senderSentinelPlugin = enabledPlugins[SENTINEL_PLUGINS];
        PluginAccessInfo storage senderPlugin = enabledPlugins[plugin];

        if (senderPlugin.nextPluginPointer != address(0)) {
            revert PluginAlreadyEnabled(msg.sender, plugin);
        }

        bool requiresRootAccess = IPluginBase(plugin).requiresRootAccess();
        if (allowRootAccess != requiresRootAccess) {
            revert PluginAccessMismatch(plugin, requiresRootAccess, allowRootAccess);
        }

        // bool grantsPluginAccess = IPluginBase(plugin).grantsPluginAccess();

        if (senderSentinelPlugin.nextPluginPointer == address(0)) {
            senderSentinelPlugin.rootAddressGranted = false;
            senderSentinelPlugin.nextPluginPointer = SENTINEL_PLUGINS;
        }

        senderPlugin.nextPluginPointer = senderSentinelPlugin.nextPluginPointer;
        senderPlugin.rootAddressGranted = allowRootAccess;
        // senderPlugin.pluginAccessGranted = grantsPluginAccess;
        senderSentinelPlugin.nextPluginPointer = plugin;

        emit PluginEnabled(msg.sender, plugin, allowRootAccess);
    }

    /**
     * @notice Disable a plugin. This function should be called by Safe.
     * @param plugin Plugin to be disabled
     */
    function _disablePlugin(address prevPlugin, address plugin) internal noZeroOrSentinelPlugin(plugin) {
        PluginAccessInfo storage prevPluginInfo = enabledPlugins[prevPlugin];
        PluginAccessInfo storage pluginInfo = enabledPlugins[plugin];

        if (prevPluginInfo.nextPluginPointer != plugin) {
            revert InvalidPrevPluginAddress(prevPlugin);
        }

        prevPluginInfo = pluginInfo;

        pluginInfo.nextPluginPointer = address(0);
        pluginInfo.rootAddressGranted = false;
        emit PluginDisabled(_accountAddress(), plugin);
    }

    /**
     * @notice A view only function to get information about safe and a plugin
     * @param plugin Address of a plugin
     */

    function getPluginInfo(address plugin) public view returns (PluginAccessInfo memory enabled) {
        return enabledPlugins[plugin];
    }

    /**
     * @notice Returns if an plugin is enabled
     * @return enabled True if the plugin is enabled
     */
    function isPluginEnabled(address plugin) public view returns (bool enabled) {
        enabled = SENTINEL_PLUGINS != plugin && enabledPlugins[plugin].nextPluginPointer != address(0);
        // && enabledPlugins[plugin].pluginAccessGranted == false; // TODO check
    }

    function isPluginEnabled(address plugin, PluginAccessInfo memory pluginAccessInfo)
        internal
        pure
        returns (bool enabled)
    {
        enabled = SENTINEL_PLUGINS != plugin && pluginAccessInfo.nextPluginPointer != address(0);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _rejectCalltoAccountOrManager(address to) private {
        if (to == address(this) || to == _accountAddress()) {
            revert InvalidToFieldInSafeProtocolAction(_accountAddress(), bytes32(0), 0);
        }
    }

    /**
     * @notice calls a plugin and returns the result
     * @param to plugin address
     * @param value ETH value
     * @param data ABI encoded calldata
     *
     * @return success True if the transaction was successful
     * @return returnData Return data of the plugin execution
     */

    function _execPlugin(address to, uint256 value, bytes memory data)
        internal
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = to.call{value: value}(data);
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
    function getPluginsPaginated(address start, uint256 pageSize)
        external
        view
        returns (address[] memory array, address next)
    {
        if (pageSize == 0) {
            revert ZeroPageSizeNotAllowed();
        }

        if (!(start == SENTINEL_PLUGINS || isPluginEnabled(start))) {
            revert InvalidPluginAddress(start);
        }
        // Init array with max page size
        array = new address[](pageSize);

        // Populate return array
        uint256 pluginCount;
        next = enabledPlugins[start].nextPluginPointer;
        while (next != address(0) && next != SENTINEL_PLUGINS && pluginCount < pageSize) {
            array[pluginCount] = next;
            next = enabledPlugins[next].nextPluginPointer;
            pluginCount++;
        }

        // This check is required because the enabled plugin list might not be initialised yet. e.g. no enabled plugins for a safe ever before
        if (pluginCount == 0) {
            next = SENTINEL_PLUGINS;
        }

        /**
         * Because of the argument validation, we can assume that the loop will always iterate over the valid plugin list values
         *       and the `next` variable will either be an enabled plugin or a sentinel address (signalling the end).
         *
         *       If we haven't reached the end inside the loop, we need to set the next pointer to the last element of the plugins array
         *       because the `next` variable (which is a plugin by itself) acting as a pointer to the start of the next page is neither
         *       included to the current page, nor will it be included in the next one if you pass it as a start.
         */
        if (next != SENTINEL_PLUGINS && pluginCount != 0) {
            next = array[pluginCount - 1];
        }
        // Set correct size of returned array
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(array, pluginCount)
        }
    }
    /*//////////////////////////////////////////////////////////////
                              VIRTUAL
    //////////////////////////////////////////////////////////////*/

    function _enforceRegistryCheck(address pluginImpl) internal view virtual;

    function _execTransationOnSmartAccount(address account, address to, uint256 value, bytes memory data)
        internal
        virtual
        returns (bool, bytes memory);
    function _execTransationOnSmartAccount(address to, uint256 value, bytes memory data)
        internal
        virtual
        returns (bool, bytes memory);

    function _execDelegateCallOnSmartAccount(address to, uint256 value, bytes memory data)
        internal
        virtual
        returns (bool, bytes memory);

    function _accountAddress() internal virtual returns (address);

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
    event ActionsExecuted(address indexed account, bytes32 metadataHash, uint256 nonce);
    event RootAccessActionExecuted(address indexed account, bytes32 metadataHash);
    event PluginEnabled(address indexed account, address indexed plugin, bool allowRootAccess);
    event PluginDisabled(address indexed account, address indexed plugin);

    /*//////////////////////////////////////////////////////////////
                              ERROR
    //////////////////////////////////////////////////////////////*/
    error PluginRequiresRootAccess(address sender);
    error PluginNotEnabled(address plugin);
    error PluginEnabledOnlyForRootAccess(address plugin);
    error PluginAccessMismatch(address plugin, bool requiresRootAccess, bool providedValue);
    error ActionExecutionFailed(address account, bytes32 metadataHash, uint256 index);
    error RootAccessActionExecutionFailed(address account, bytes32 metadataHash);
    error PluginAlreadyEnabled(address account, address plugin);
    error InvalidPluginAddress(address plugin);
    error InvalidPrevPluginAddress(address plugin);
    error ZeroPageSizeNotAllowed();
    error InvalidToFieldInSafeProtocolAction(address account, bytes32 metadataHash, uint256 index);
}
