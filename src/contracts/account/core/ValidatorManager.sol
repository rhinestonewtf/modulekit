// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SentinelListLib} from "sentinellist/src/SentinelList.sol";
import {IValidatorModule} from "../../modules/validators/IValidatorModule.sol";

import "forge-std/console2.sol";

abstract contract ValidatorManager {
    using SentinelListLib for SentinelListLib.SentinelList;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);
    event RecoveryAdded(address indexed validator, address indexed recovery);
    event DefaultRecoverySet(address indexed recovery);
    event DefaultValidatorSet(address indexed validator);
    event TrustedAuthoritySet(address indexed trustedAuthority);
    event ValidatorRecovered(address indexed validator, address indexed recovery);

    SentinelListLib.SentinelList internal validatorList;
    address internal DEFAULT_RECOVERY;
    mapping(address validator => address recovery) internal recoveryByValidator;

    function _initializeValidatorManager(address defaultRecovery) internal {
        validatorList.init();
        DEFAULT_RECOVERY = defaultRecovery;
    }

    /*//////////////////////////////////////////////////////////////
                              Validators
    //////////////////////////////////////////////////////////////*/
    function _addValidator(address validator) internal {
        _enforceRegistryCheck(validator);
        validatorList.push(validator);
        emit ValidatorAdded(validator);
    }

    function _addValidator(address validator, address recovery) internal {
        _addValidator(validator);
        _setRecovery({validator: validator, recovery: recovery});
    }

    function _removeValidator(address prevValidator, address removeValidator) internal {
        validatorList.pop({prevEntry: prevValidator, popEntry: removeValidator});
    }

    function isEnabledValidator(address validator) public view returns (bool enabled) {
        enabled = validatorList.contains(validator);
    }

    function getAllValidators(address startInList, uint256 pageSize)
        public
        view
        returns (address[] memory, address next)
    {
        return validatorList.getEntriesPaginated(startInList, pageSize);
    }

    /*//////////////////////////////////////////////////////////////
                              Recovery
    //////////////////////////////////////////////////////////////*/
    function getRecovery(address validator) public view returns (address recovery) {
        recovery = recoveryByValidator[validator];
        if (recovery == address(0)) {
            recovery = DEFAULT_RECOVERY;
        }
    }

    function _setRecovery(address validator, address recovery) internal {
        if (validator == address(0)) DEFAULT_RECOVERY = recovery;
        else recoveryByValidator[validator] = recovery;
        emit RecoveryAdded(validator, recovery);
    }

    function _recoverValidator(address validator, bytes calldata recoveryProof, bytes calldata recoveryData) internal {
        address recoveryModule = getRecovery(validator);
        IValidatorModule(validator).recoverValidator(recoveryModule, recoveryProof, recoveryData);
        emit ValidatorRecovered(validator, recoveryModule);
    }

    function _enforceRegistryCheck(address executorImpl) internal view virtual;
}
