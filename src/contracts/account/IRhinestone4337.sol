// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../modules/plugin/IPluginBase.sol";
import "@aa/interfaces/UserOperation.sol";

interface IRhinestone4337 {
    /*//////////////////////////////////////////////////////////////
                            INIT
    //////////////////////////////////////////////////////////////*/

    function initialize(
        address _owner,
        address _defaultValidator,
        address _defaultRecovery,
        address _registry,
        address _trustedAuthority,
        address _cloneFactory
    ) external;

    /*//////////////////////////////////////////////////////////////
                            ERC 4337
    //////////////////////////////////////////////////////////////*/

    // function getPluginsPaginated(address start, uint256 pageSize)
    //     external
    //     returns (address[] memory array, address next);

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 requiredPrefund)
        external
        returns (uint256);

    function checkAndExecTransactionFromModule(
        address smartAccount,
        address target,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 nonce
    ) external;

    /**
     * @dev Gets the clone of a plugin
     *
     * @param pluginImpl Address of the plugin
     * @param salt Random nonce
     * @return clone Address of the plugin clone
     */
    function clones(address pluginImpl, bytes32 salt) external view returns (address clone);

    /*//////////////////////////////////////////////////////////////
                              MANAGE VALIDATORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Adds a validator
     *
     * @param validator Address of the validator
     */
    function addValidator(address validator) external;
    function addValidatorAndRecovery(address validator, address recovery) external;

    /**
     * @dev Removes a validator
     *
     * @param prevValidator Address of the previous validator in list
     * @param validator Address of the validator
     */
    function removeValidator(address prevValidator, address validator) external;

    /**
     * @dev Adds a recovery module for a validator
     *
     * @param validator Address of the validator
     * @param recovery Address of the recovery module
     */
    function addRecovery(address validator, address recovery) external;

    /*//////////////////////////////////////////////////////////////
                              RECOVERY
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Sets the default recovery module
     *
     * @param recovery Address of the recovery module
     */
    function setDefaultRecovery(address recovery) external;

    /**
     * @dev Recovers a validator
     *
     * @param validator Address of the validator
     * @param recoveryProof The proof required for recovery
     * @param recoveryData The data required for recovery
     */
    function recoverValidator(address validator, bytes calldata recoveryProof, bytes calldata recoveryData) external;
}
