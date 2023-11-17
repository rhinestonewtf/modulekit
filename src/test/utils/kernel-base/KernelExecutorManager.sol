// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "src/core/ExecutorManager.sol";
import "./IKernel.sol";

contract KernelExecutorManager is ExecutorManager, IKernelValidator {
    constructor(IERC7484Registry _registry) ExecutorManager(_registry) { }
    function enable(bytes calldata _data) external payable override { }

    function disable(bytes calldata _data) external payable override { }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingFunds
    )
        external
        payable
        override
        returns (ValidationData)
    { }

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
        return isExecutorEnabled(msg.sender, caller);
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
        success = true;
        IKernel(account).execute(to, value, data, Operation.Call);
        assembly {
            let size := returndatasize()
            mstore(retData, size) // Set the length prefix
            returndatacopy(add(retData, 0x20), 0, size) // Copy the returned data
        }
    }
}
