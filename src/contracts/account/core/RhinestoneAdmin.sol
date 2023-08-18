// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*//////////////////////////////////////////////////////////////
                          Auxillary Contracts
//////////////////////////////////////////////////////////////*/

import {Ownable} from "solady/auth/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/*//////////////////////////////////////////////////////////////
                          Rhinestone Components
//////////////////////////////////////////////////////////////*/

import {ModuleManager} from "./ModuleManager.sol";
import {IRhinestone4337} from "../IRhinestone4337.sol";
import {ValidatorManager} from "./ValidatorManager.sol";
import {IValidatorModule} from "../../modules/validators/IValidatorModule.sol";
import {RegistryAdapter} from "./RegistryAdapter.sol";

/// @title Rhinestone4337
/// @author zeroknots

abstract contract RhinestoneAdmin is
    Ownable,
    Initializable,
    IRhinestone4337,
    ModuleManager,
    ValidatorManager,
    RegistryAdapter
{
    /**
     * @dev Initializes the Rhinestone Admin contract
     *
     * @param _owner Address of the contract owner
     * @param _defaultValidator Address of the default validator
     * @param _defaultRecovery Address of the default recovery module
     * @param _registry Address of the module registry
     * @param _trustedAuthority Address of the trusted authority
     * @param _cloneFactory Address of the clone factory
     */
    function initialize(
        address _owner,
        address _defaultValidator,
        address _defaultRecovery,
        address _registry,
        address _trustedAuthority,
        address _cloneFactory
    ) external initializer {
        _initializeOwner(msg.sender);
        _initializeModuleManager(_cloneFactory);
        _initializeRegistryAdapter(_registry, _trustedAuthority);
        _initializeValidatorManager(_defaultRecovery);
        _addValidator(_defaultValidator);
    }

    function _enforceRegistryCheck(address pluginImpl)
        internal
        view
        override(ModuleManager, RegistryAdapter, ValidatorManager)
    {
        super._enforceRegistryCheck(pluginImpl);
    }

    /**
     * @inheritdoc IRhinestone4337
     */
    function clones(address pluginImpl, bytes32 salt) external view override returns (address) {
        return pluginImplToClones[pluginImpl][salt];
    }

    /*//////////////////////////////////////////////////////////////
                              MANAGE PLUGINS
    //////////////////////////////////////////////////////////////*/
    /**
     * @inheritdoc IRhinestone4337
     */
    function enablePlugin(address plugin, bool allowRootAccess) external onlyOwner {
        _enablePlugin(plugin, allowRootAccess);
    }

    function getPluginsPaginated(address start, uint256 pageSize)
        public
        view
        override(IRhinestone4337, ModuleManager)
        returns (address[] memory array, address next)
    {
        return super.getPluginsPaginated(start, pageSize);
    }

    /**
     * @inheritdoc IRhinestone4337
     */
    function enablePluginClone(address plugin, bool allowRootAccess, bytes32 salt) external override onlyOwner {
        address clone = _clonePlugin(plugin, salt);
        _enablePlugin(clone, allowRootAccess);
    }

    /**
     * @inheritdoc IRhinestone4337
     */
    function enablePluginCloneInit(address plugin, bool allowRootAccess, bytes calldata initCallData, bytes32 salt)
        external
        override
        onlyOwner
    {
        address clone = _clonePlugin(plugin, initCallData, salt);
        _enablePlugin(clone, allowRootAccess);
    }

    /**
     * @inheritdoc IRhinestone4337
     */
    function disablePlugin(address prevPlugin, address plugin) external onlyOwner {
        _disablePlugin(prevPlugin, plugin);
    }

    /*//////////////////////////////////////////////////////////////
                              MANAGE VALIDATORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @inheritdoc IRhinestone4337
     */
    function addValidator(address validator) external onlyOwner {
        _addValidator(validator);
    }

    function addValidatorAndRecovery(address validator, address recovery) external onlyOwner {
        _addValidator(validator, recovery);
    }

    // TODO: add default validator

    /**
     * @inheritdoc IRhinestone4337
     */
    function removeValidator(address prevValidator, address validator) external onlyOwner {
        _removeValidator(prevValidator, validator);
    }

    /**
     * @inheritdoc IRhinestone4337
     */
    function addRecovery(address validator, address recovery) external onlyOwner {
        _setRecovery(validator, recovery);
    }

    /*//////////////////////////////////////////////////////////////
                              RECOVERY
    //////////////////////////////////////////////////////////////*/
    /**
     * @inheritdoc IRhinestone4337
     */
    function setDefaultRecovery(address recovery) external onlyOwner {
        // this sets the default recovery module
        _setRecovery({validator: address(0), recovery: recovery});
    }

    /**
     * @inheritdoc IRhinestone4337
     */
    function recoverValidator(address validator, bytes calldata recoveryProof, bytes calldata recoveryData) external {
        // RECOVER SHOULD BE EXTERNAL
        // bytes32 executionHash = keccak256(abi.encode(validator, recoveryProof, recoveryData));
        // ExecutionStatus memory status = hashes[executionHash];
        // require(status.approved && !status.executed, "Unexpected status");
        // hashes[executionHash].executed = true;
        address recoveryModule = getRecovery(validator);
        IValidatorModule(validator).recoverValidator(recoveryModule, recoveryProof, recoveryData);
    }

    /*//////////////////////////////////////////////////////////////
                              Virtual
    //////////////////////////////////////////////////////////////*/

    function _msgSender() internal view virtual returns (address sender);
}
