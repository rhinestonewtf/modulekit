// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SentinelListLib} from "sentinellist/src/SentinelList.sol";

import "forge-std/console2.sol";

abstract contract ValidatorManager {
    using SentinelListLib for SentinelListLib.SentinelList;

    event EnabledValidator(address validator);

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
        emit EnabledValidator(validator);
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
    }

    function _enforceRegistryCheck(address executorImpl) internal view virtual;
}
