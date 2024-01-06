// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ISessionValidationModule {
    /**
     * @dev validates that the call (destinationContract, callValue, funcCallData)
     * complies with the Session Key permissions represented by sessionKeyData
     * @param to address of the contract to be called
     * @param value value to be sent with the call
     * @param callData the data for the call.
     * is parsed inside the Session Validation Module (SVM)
     * @param sessionKeyData SessionKey data, that describes sessionKey permissions
     */
    function validateSessionParams(
        address to,
        uint256 value,
        bytes calldata callData,
        bytes calldata sessionKeyData,
        bytes calldata callSpecificData
    )
        external
        returns (address);
}
