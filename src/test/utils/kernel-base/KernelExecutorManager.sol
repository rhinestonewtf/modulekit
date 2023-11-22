// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "src/core/ExecutorManager.sol";
import "./IKernel.sol";
import { IValidator } from "src/modulekit/interfaces/IValidator.sol";
import { SentinelListLib } from "sentinellist/src/SentinelList.sol";

import "forge-std/console2.sol";

contract KernelExecutorManager is ExecutorManager, IKernelValidator {
    using SentinelListLib for SentinelListLib.SentinelList;

    mapping(address account => SentinelListLib.SentinelList validators) internal validators;

    constructor(IERC7484Registry _registry) ExecutorManager(_registry) { }

    function enable(bytes calldata _data) external payable override {
        validators[msg.sender].init();
    }

    function disable(bytes calldata _data) external payable override { }
    /**
     * Adds a validator.
     * @dev queries the registry with ERC-7484 to ensure that the validator is trusted.
     * @param validator - Address of the validator to be added.
     */

    function addValidator(address validator) external onlySecureModule(validator) {
        validators[msg.sender].push(validator);
    }

    /**
     * @dev Returns paginated list of validators.
     * @param start - Starting address for the pagination.
     * @param pageSize - Number of entries per page.
     * @param account - Account whose validators are to be fetched.
     */
    function getValidatorPaginated(
        address start,
        uint256 pageSize,
        address account
    )
        external
        view
        returns (address[] memory array, address next)
    {
        return validators[account].getEntriesPaginated(start, pageSize);
    }

    /**
     * @dev Removes a validator.
     * @param prevValidator - Address of the previous validator in the list.
     * @param delValidator - Address of the validator to be removed.
     */
    function removeValidator(address prevValidator, address delValidator) external {
        validators[msg.sender].pop({ prevEntry: prevValidator, popEntry: delValidator });
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingFunds
    )
        external
        payable
        override
        returns (ValidationData retData)
    {
        address payable kernelAddress = payable(userOp.sender);

        // TODO verify return
        retData = ValidationData.wrap(_validateSignatures(userOp, userOpHash));
    }

    function isValidatorEnabled(address account, address validator) public view returns (bool) {
        return validators[account].contains(validator);
    }

    function _validateSignatures(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        internal
        returns (uint256 ret)
    {
        // get operation target from userOp
        // (, address target,,,,) =
        //     abi.decode(userOp.callData[4:], (address, address, uint256, bytes, uint8, uint256));

        // get validators for target
        address validator;
        uint256 sigLength = userOp.signature.length;

        if (sigLength == 0) return 0;
        else (, validator) = abi.decode(userOp.signature, (bytes, address));

        // check if selected validator is enabled
        require(isValidatorEnabled(userOp.sender, validator), "Validator not enabled");

        ret = IValidator(validator).validateUserOp(userOp, userOpHash);
        require(ret == 0, "Invalid signature");
    }

    function validateSignature(
        bytes32 hash,
        bytes calldata signature
    )
        external
        view
        override
        returns (ValidationData)
    { }

    function validCaller(
        address caller,
        bytes calldata data
    )
        external
        view
        override
        returns (bool)
    {
        // TODO use TSTORE / TLOAD to get exec context
        if (caller == address(this)) return true;
    }

    function _execTransationOnSmartAccount(
        address account,
        address to,
        uint256 value,
        bytes memory data
    )
        internal
        virtual
        override
        returns (bool success, bytes memory retData)
    {
        bytes memory callData = abi.encodeWithSelector(
            IKernel(account).execute.selector, to, value, data, Operation.Call
        );
        (success,) = account.call(callData);

        assembly {
            let size := returndatasize()
            mstore(retData, size) // Set the length prefix
            returndatacopy(add(retData, 0x20), 0, size) // Copy the returned data
        }
        console2.log("called kernel");
    }
}
