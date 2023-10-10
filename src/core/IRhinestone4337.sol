// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../modulekit/IExecutor.sol";
import "../common/erc4337/UserOperation.sol";

interface IRhinestone4337 {
    function init(address validator) external;

    /*//////////////////////////////////////////////////////////////
                            ERC 4337
    //////////////////////////////////////////////////////////////*/

    // function getexecutorsPaginated(address start, uint256 pageSize)
    //     external
    //     returns (address[] memory array, address next);

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPrefund
    )
        external
        returns (uint256);

    function checkAndExecTransactionFromModule(
        address smartAccount,
        address target,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 nonce
    )
        external;

    /*//////////////////////////////////////////////////////////////
                              MANAGE VALIDATORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Adds a validator
     *
     * @param validator Address of the validator
     */
    function addValidator(address validator) external;

    function getValidatorPaginated(
        address start,
        uint256 pageSize,
        address account
    )
        external
        view
        returns (address[] memory array, address next);

    function isEnabledValidator(address account, address validator) external view returns (bool);

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

    /**
     * @dev Makes an external call with the manager. this is used to config validators / singletons
     *
     * @param target  Address of the target
     * @param callData Data to send to the target
     */
    function forwardCall(
        address target,
        bytes calldata callData
    )
        external
        returns (bool success, bytes memory returnData);

    /*//////////////////////////////////////////////////////////////
                              RECOVERY
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Recovers a validator
     *
     * @param validator Address of the validator
     * @param recoveryProof The proof required for recovery
     * @param recoveryData The data required for recovery
     */
    function recoverValidator(
        address validator,
        bytes calldata recoveryProof,
        bytes calldata recoveryData
    )
        external;
}
