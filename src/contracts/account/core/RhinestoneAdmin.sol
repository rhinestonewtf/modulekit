// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*//////////////////////////////////////////////////////////////
                          Auxillary Contracts
//////////////////////////////////////////////////////////////*/

import {Ownable} from "solady/src/auth/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/*//////////////////////////////////////////////////////////////
                          Rhinestone Components
//////////////////////////////////////////////////////////////*/

import {IRhinestone4337} from "../IRhinestone4337.sol";
import {ValidatorManager} from "./ValidatorManager.sol";
import {RegistryAdapter} from "./RegistryAdapter.sol";

/// @title Rhinestone4337
/// @author zeroknots

abstract contract RhinestoneAdmin is Ownable, Initializable, IRhinestone4337, ValidatorManager, RegistryAdapter {
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
        _setRegistry(_registry);
        _initializeOwner(msg.sender);
        _initializeValidatorManager(_defaultRecovery);
        _addValidator(_defaultValidator);
    }

    function _enforceRegistryCheck(address executorImpl) internal view override(RegistryAdapter, ValidatorManager) {
        super._enforceRegistryCheck(executorImpl);
    }

    /**
     * @inheritdoc IRhinestone4337
     */
    function clones(address executorImpl, bytes32 salt) external view override returns (address) {
        // return executorImplToClones[executorImpl][salt];
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
    function removeValidator(address validator, address prevValidator) external onlyOwner {
        _removeValidator(validator, prevValidator);
    }

    /**
     * @inheritdoc IRhinestone4337
     */
    function addRecovery(address validator, address recovery) external onlyOwner {
        _setRecovery(validator, recovery);
    }

    function removeRecovery(address validator) external onlyOwner {
        _removeRecovery(validator);
    }

    function forwardCall(address target, bytes calldata callData)
        external
        onlyOwner
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = target.call(callData);
        if (!success) returnData = bytes("");
        else returnData = returnData;
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

    /*//////////////////////////////////////////////////////////////
                              Virtual
    //////////////////////////////////////////////////////////////*/

    function _msgSender() internal view virtual returns (address sender);
}
